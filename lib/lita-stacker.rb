# frozen_string_literal: true

require 'lita'

Lita.load_locales Dir[File.expand_path(
  File.join('..', '..', 'locales', '*.yml'), __FILE__
)]

require 'lita/handlers/stacker'
require 'lita/handlers/stacker/upgrade/sorted_sets'
