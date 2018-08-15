# frozen_string_literal: true

module Lita
  module Handlers
    class Stacker
      module Upgrade
        class SortedSets
          extend Lita::Handler::EventRouter

          namespace 'stacker'
          on :loaded, :update_store

          # To prevent disrupting stacks in progress, set a window smaller than the default timeout
          # for them to be valid.
          config :timeout, type: Integer, default: 2 * 60 * 60 # 2.hours
          config :offset, type: Float, default: 0.1

          SUPPORT_KEY = 'support:zsets'

          def update_store(_payload)
            return if redis.exists(SUPPORT_KEY)

            redis.keys.each do |key|
              next unless redis.type(key) == 'list'
              list = redis.lrange(key, 0, -1)
              list = list.uniq

              redis.del(key)

              # Add an offset so the scores are not identical
              offset = config.offset
              values = list.each_with_index.map { |name, i| [Time.now.to_f - config.timeout + offset * i, name] }
              redis.zadd(key, values)
            end

            redis.incr(SUPPORT_KEY)
          end
        end
      end
    end
  end
end

Lita.register_handler(Lita::Handlers::Stacker::Upgrade::SortedSets)
