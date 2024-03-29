# frozen_string_literal: true

RSpec.describe Lita::Handlers::Stacker::Upgrade::SortedSets, lita_handler: true do
  before { subject.redis.del(Lita::Handlers::Stacker::Upgrade::SortedSets::SUPPORT_KEY) }

  after { subject.redis.del(Lita::Handlers::Stacker::Upgrade::SortedSets::SUPPORT_KEY) }

  let(:payload) { {} }

  it 'increments the support flag' do
    subject.update_store(payload)
    expect(subject.redis.exists?(Lita::Handlers::Stacker::Upgrade::SortedSets::SUPPORT_KEY)).to be true
  end

  context 'when there are stores to upgrade' do
    let(:arthur) { Lita::User.create(42, name: 'Arthur', mention_name: 'arthur') }
    let(:ford) { Lita::User.create(23, name: 'Ford', mention_name: 'ford') }
    let(:trillian) { Lita::User.create(456, name: 'Tricia MacMillian', mention_name: 'trillian') }
    let(:zaphod) { Lita::User.create(123, name: 'Zaphod', mention_name: 'zaphod') }

    let(:lists) do
      {
        channel: %w[zaphod trillian ford arthur],
        channel_with_duplicates: %w[zaphod trillian ford marvin zaphod arthur zaphod marvin ford marvin]
      }
    end

    let(:users) { [zaphod, trillian, ford, arthur] }

    before do
      users
      lists.each { |channel, names| subject.redis.rpush(channel, names) }
    end

    it 'changes the types to sorted sets' do
      subject.update_store(payload)
      lists.each { |channel, _names| expect(subject.redis.type(channel)).to eq 'zset' }
    end

    it 'maintains the same order for the set' do
      subject.update_store(payload)
      expect(subject.redis.zrangebyscore(:channel, '-inf', '+inf')).to eq users.map(&:id)
    end

    it 'removes duplicate and invalid stacks, maintaining the correct order' do
      subject.update_store(payload)
      expect(subject.redis.zrangebyscore(:channel_with_duplicates, '-inf', '+inf')).to eq users.map(&:id)
    end
  end
end
