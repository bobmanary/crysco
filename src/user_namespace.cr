require "./syscalls"
require "lib_c"
require "./container"

module Crysco::UserNamespace
  USER_NAMESPACE_UID_PARENT_RANGE_START = 0
  USER_NAMESPACE_UID_CHILD_RANGE_START = 10000
  USER_NAMESPACE_UID_CHILD_RANGE_SIZE = 2000

  # Lets the parent process know that the user namespace is started.
  # The parent calls user_namespace_set_user to update the uid_map / gid_map.
  # If successful, setgroups, setresgid, and setresuid are called in this
  # function by the child. setgroups and setresgid are necessary because of two
  # separate group mechanisms on Linux. The function assumes that every uid has a
  # corresponding gid, which is often the case.
  def self.init(uid : UInt32, child_socket : UNIXSocket) : Bool
    Log.debug {"Setting user namespace..."}

    unshared : Int32 = Syscalls.unshare(Syscalls::ProcFlags::CLONE_NEWUSER)

    Log.debug {"Writing to socket..."}
    # can't write a single boolean to socket, so use an int
    # (0 == success)
    child_socket.write_bytes(unshared)

    # wait for parent process to set up user namespace mapping
    Log.debug {"Reading from socket"}
    result : Int32 = child_socket.read_bytes(Int32)

    if result != 0
      return false
    end

    Log.debug {"Switching to uid #{uid} and gid #{uid}"}

    Log.debug {"Setting uid and gid mappings..."}
    c_uids = StaticArray(LibC::UidT, 1).new(uid)
    if (
      LibC.setgroups(1u64, c_uids) != 0 ||
      LibC.setresgid(uid, uid, uid) != 0 ||
      LibC.setresuid(uid, uid, uid) != 0
    )
      Log.error {"Failed to set uid #{uid} / gid #{uid} mappings"}
      sleep 0.1
      return false
    end

    Log.debug {"User namespace set"}

    true
  end

  # Listens for the child process to request setting uid / gid, then updates the
  # uid_map / gid_map for the child process to use. uid_map and gid_map are a
  # Linux kernel mechanism for mapping uids and gids between the parent and child
  # process. The parent process must be privileged to set the uid_map / gid_map.
  def self.prepare_mappings(container_process : Container, parent_socket : UNIXSocket) : Bool
    Log.debug {"Updating uid_map / gid_map..."}

    Log.debug {"Retrieving user namespaces status..."}
    unshared : Int32 = parent_socket.read_bytes(Int32)

    if unshared == 0
      Log.debug {"User namespaces enabled"}

      Log.debug {"Writing uid_map / gid_map..."}
      {"uid_map", "gid_map"}.each do |map_filename|
        # eg /proc/123/uid_map
        map_path = Path["/proc", container_process.pid.to_s, map_filename]

        Log.debug {"Writing #{map_path}"...}

        mapping = "#{USER_NAMESPACE_UID_PARENT_RANGE_START} #{USER_NAMESPACE_UID_CHILD_RANGE_START} #{USER_NAMESPACE_UID_CHILD_RANGE_SIZE}"
        begin
          File.write(map_path, mapping, mode: "w")
        rescue exception
          Log.error {"Failed to write #{map_filename}"}
          return false
        end
      end

      Log.debug {"uid_map and gid_map updated"}
    end

    Log.debug {"Updating socket..."}
    parent_socket.write_bytes(0)

    return true
  end
end

lib LibC
  fun setgroups(n : SizeT, groups : GidT*) : LibC::Int
  fun setresgid(real_gid : GidT, effective_gid : GidT, savedset_gid : GidT) : LibC::Int
  fun setresuid(real_uid : UidT, effective_uid : UidT, savedset_uid : UidT) : LibC::Int
end
