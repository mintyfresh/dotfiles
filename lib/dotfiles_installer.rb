# frozen_string_literal: true

require_relative 'installer'

# @return [Installer]
def dotfiles_installer
  installer = Installer.new

  installer.add 'rails/.railsrc'

  installer
end
