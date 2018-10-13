# frozen_string_literal: true

require 'rubocop'

RSpec.describe RuboCop do
  it 'passes' do
    result = RuboCop::CLI.new.run(['-f', 'simple', File.expand_path('../..', __dir__)])
    expect(result).to eq(0)
  end
end
