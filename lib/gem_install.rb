module GemInstall
  def self.req(*mods)
    mods.each { |mod|
      name = mod
      rname = name
      if mod.is_a? Array then
        name = mod[0]
        rname = mod[1]
      end
      puts "Installing gem(#{name}) ..."
      begin
        require 'rubygems/commands/install_command'
        cmd = Gem::Commands::InstallCommand.new
        cmd.handle_options ["--no-ri", "--no-rdoc", name]
        cmd.execute
      rescue Gem::SystemExitException => e
        puts "DONE: #{e.exit_code}"
      end
      require rname
    }
  end
end
