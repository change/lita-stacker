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
              update_key(key)
            end

            redis.incr(SUPPORT_KEY)
          end

          private

          def update_key(key)
            return unless redis.type(key) == 'list'
            list = redis.lrange(key, 0, -1).uniq

            redis.del(key)

            values = list_scores(list)
            redis.zadd(key, values)
          end

          def list_scores(list)
            # Add an offset so the scores are not identical
            offset = config.offset
            list.each_with_index.each_with_object([]) do |(name, i), l|
              user = Lita::User.find_by_mention_name(name) || Lita::User.find_by_name(name)
              l.push([Time.now.to_f - config.timeout + offset * i, user.id]) if user
            end
          end
        end
      end
    end
  end
end

Lita.register_handler(Lita::Handlers::Stacker::Upgrade::SortedSets)
