require "file_utils"

module Crysco
  class CgroupsSetting
    property name : String
    property value : String
    def initialize(@name, @value)
    end
  end

  module Cgroups
    def self.apply(hostname, pid) : Bool
      cgroup_path = Path.new("/sys", "fs", "cgroup", hostname)

      begin
        Dir.mkdir(cgroup_path, 0o700)
        if !Dir.exists?(cgroup_path)
          Log.error { "Failed to make directory #{cgroup_path}" }
          return false
        end
      rescue err : File::AlreadyExistsError
        # should we bail out here? probably?
      end

      cgroups_settings = [
        {"memory.max", "1G"},
        {"cpu.weight", "256"},
        {"pids.max", "64"},
        {"cgroup.procs", pid.to_s},
      ]

      cgroups_settings.each do |setting|
        Log.debug {"setting #{setting[0]} to #{setting[1]} (#{cgroup_path / setting[0]})"}
        File.write(cgroup_path / setting[0], setting[1], mode: "w")
      end

      Log.debug { "cgroups set" }
      return true
    end

    def self.free(hostname)
      cgroup_path = Path.new("/sys", "fs", "cgroup", hostname)
      FileUtils.rmdir(cgroup_path)
      Log.debug { "cgroups released" }
    end
  end
end
