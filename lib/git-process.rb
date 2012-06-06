require File.expand_path('../git-lib', __FILE__)

module Git

  class Process
    attr_reader :lib

    def initialize(dir, options = {})
      @lib = Git::GitLib.new(dir, options)
    end


    def rebase_to_master(remote = true)
      if !lib.clean_status?
        raise UncommittedChangesError.new
      end
      lib.fetch if remote
      rebase(if remote then "origin/master" else "master" end)
      lib.push("origin", "master") if remote
    end


    def sync_with_server
      if !lib.clean_status?
        raise UncommittedChangesError.new
      end
      lib.fetch
      rebase("origin/master")
      if lib.current_branch != 'master'
        lib.push("origin", lib.current_branch)
      else
        logger.warn("Not pushing to the server because the current branch is the master branch.")
      end
    end


    def rebase(base)
      begin
        lib.rebase(base)
      rescue => rebase_error_message
        handle_rebase_error(rebase_error_message)
      end
    end


    def git
      lib.git
    end


    private


    def logger
      @lib.logger
    end


    def handle_rebase_error(rebase_error_message)
      logger.warn("Handling rebase error")

      git.status.each do |status|
        if remerged_file?(status, rebase_error_message)
          lib.add(status.path)
        end
      end

      if lib.clean_status?
        lib.rebase_continue
      end

    end


    def remerged_file?(status, rebase_error_message)
      status.type == 'M' and
      status.stage == '3' and
      /Resolved '#{status.path}' using previous resolution./m =~ rebase_error_message
    end


    class GitProcessError < RuntimeError
    end


    class UncommittedChangesError < GitProcessError
      def initialize()
        super("There are uncommitted changes.\nPlease either commit your changes, or use 'git stash' to set them aside.")
      end
    end

  end

end
