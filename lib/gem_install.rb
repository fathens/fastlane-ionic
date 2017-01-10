module GemInstall
  def self.run(name)
    puts "Installing gem(#{name}) ..."
    begin
      require 'rubygems/commands/install_command'
      cmd = Gem::Commands::InstallCommand.new
      cmd.handle_options ["--no-ri", "--no-rdoc", name]
      cmd.execute
    rescue Gem::SystemExitException => e
      puts "DONE: #{e.exit_code}"
    end
  end
end
