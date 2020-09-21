module Agents
  class LndChannelStatusAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule '1h'

    description do
      <<-MD
      The Github notification agent fetches notifications and creates an event by notification.

      `mark_as_read` is used to post request for mark as read notification.

      `result_limit` is used when you want to limit result per page.

      `real_value` is used for calculating token value with the tokenDecimal applied.

      `with_confirmations` is used to avoid an event as soon as it increases.

      `type` can be tokentx type (you can see api documentation).
      Get a list of "ERC20 - Token Transfer Events" by Address

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "blockNumber": "XXXXXXXXX",
          "timeStamp": "XXXXXXXXXX",
          "hash": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
          "nonce": "XXXXXX",
          "blockHash": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "from": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "contractAddress": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "to": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "value": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "tokenName": "XXX",
          "tokenSymbol": "XXX",
          "tokenDecimal": "xx",
          "transactionIndex": "xx",
          "gas": "XXXXXX",
          "gasPrice": "XXXXXX",
          "gasUsed": "XXXXX",
          "cumulativeGasUsed": "XXXXXX",
          "input": "deprecated",
          "confirmations": "XXXXXX"
        }
    MD

    def default_options
      {
        'url' => '',
        'changes_only' => 'true',
        'expected_receive_period_in_days' => '2',
        'macaroon' => '',
      }
    end

    form_configurable :url, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :macaroon, type: :string
    form_configurable :expected_receive_period_in_days, type: :string
    def validate_options
      unless options['url'].present?
        errors.add(:base, "url is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['macaroon'].present?
        errors.add(:base, "macaroon is a required field")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      memory['last_status'].to_i > 0

      return false if recent_error_logs?
      
      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def check
      fetch
    end

    private

    def fetch
      uri = URI.parse("#{interpolated['url']}/v1/channels")
      request = Net::HTTP::Get.new(uri)
      request["Grpc-Metadata-Macaroon"] = "#{interpolated['macaroon']}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
        verify_mode: OpenSSL::SSL::VERIFY_NONE,
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "request  status : #{response.code}"

      payload = JSON.parse(response.body)

      if interpolated['changes_only'] == 'true'
        if payload['channels'].to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload['channels'].each do |channel|
              create_event payload: channel
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null")
            last_status = JSON.parse(last_status)
            payload['channels'].each do |channel|
              found = false
              last_status['channels'].each do |channelbis|
                if channel['chan_id'] == channelbis['chan_id'] && channel['status'] == channelbis['status']
                    found = true
                end
              end
              if found == false
                  create_event payload: channel
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        log  payload['channels']
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
