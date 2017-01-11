require 'rubygems/commands/install_command'

module GemInstall
  def self.req(*mods)
    mods.each { |mod|
      if mod.is_a? Hash then
        mod.each { |g, m| each_req(g, m) }
      else
        each_req(mod, mod)
      end
    }
  end

  private

  def self.each_req(gem_name, mod_name)
    puts "Installing gem(#{gem_name}) ..."
    begin
      cmd = Gem::Commands::InstallCommand.new
      cmd.handle_options ["--no-ri", "--no-rdoc", gem_name]
      cmd.execute
    rescue Gem::SystemExitException => e
      puts "DONE: #{e.exit_code}"
    end
    require mod_name
  end
end
