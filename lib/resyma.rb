# frozen_string_literal: true

require_relative "resyma/version"

#
# Interfaces of Resyma services
#
module Resyma
  class Error < StandardError; end
end

require_relative "resyma/language"