require "./syscalls"
require "file_utils"

module Crysco::Mount

  def self.set(mnt : Path) : Bool
    Log.debug {"Setting mount..."}

    Log.debug {"Remounting with MS_PRIVATE"}
    remount_flags = Syscalls::MountFlags::MS_REC | Syscalls::MountFlags::MS_PRIVATE
    if !mount(nil, Path["/"], remount_flags)
      Log.error {"Failed to remount /"}
      return false
    end
    Log.debug {"Remounted"}

    Log.debug {"Creating temporary directory and..."}
    tempdir = mktempdir()
    if tempdir.nil?
      Log.error {"Failed to create directory"}
      return false
    end

    Log.debug {"Bind mount..."}
    bind_mount_flags = Syscalls::MountFlags::MS_BIND | Syscalls::MountFlags::MS_PRIVATE
    if !mount(mnt, tempdir, bind_mount_flags)
      Log.error {"Failed to bind mount '#{mnt}' to '#{tempdir}'"}
      return false
    end

    temp_inner_dir = mktempdir(tempdir)
    if temp_inner_dir.nil?
      Log.error {"Failed to create inner directory"}
      return false
    end

    Log.debug {"Pivot root with #{tempdir}, #{temp_inner_dir}..."}
    # move the previous top-level / to a subdirectory and set the process's
    # root to tempdir
    if !pivot_root(tempdir, temp_inner_dir)
      Log.error {"Failed to pivot root with #{tempdir}, #{temp_inner_dir}"}
      return false
    end

    Log.debug {"Unmounting old root..."}
    old_root_dir = temp_inner_dir.basename
    old_root = Path.new("/", old_root_dir)

    Log.debug {"Changing directory to /..."}
    Dir.cd("/")
  
    Log.debug {"Unmounting #{old_root}..."}
    if !unmount(old_root)
      Log.error {"Failed to unmount #{old_root}"}
      return false
    end

    Log.debug {"Mounting /proc in new root..."}
    Dir.mkdir_p(Path["proc"])
    if !mount_proc(Path["proc"])
      Log.error {"Failed to mount proc filesystem"}
      return false
    end

    Log.debug {"Removing temporary directories..."}
    if Path["/"] == old_root
      # shouldn't happen
      Log.error {"Path was root!"}
      return false
    end
    FileUtils.rmdir(old_root)

    Log.debug {"Mount set"}
    return true
  end

  def self.mktempdir(dir : Path? = nil) : Path | Nil
    name = Path.new(
      if dir.nil?
        File.tempname(prefix: "crysco", suffix: ".d")
      else
        File.tempname(prefix: "crysco", suffix: ".d", dir: dir.to_s)
      end
    )
    Dir.mkdir(name)
    if !Dir.exists?(name)
      nil
    else
      name
    end
  end

  def self.pivot_root(new_root : Path, put_old : Path) : Bool
    Log.debug {"Calling pivot_root syscall..."}
    Syscalls.pivot_root(new_root.to_s.to_unsafe, put_old.to_s.to_unsafe) == 0
  end

  def self.mount(source : Path?, target : Path, flags : Syscalls::MountFlags) : Bool
    s = source.nil? ? nil : source.to_s
    t = target.to_s
    flag_val = flags.to_u32

    result = Syscalls.mount(
      s.nil? ? Pointer(UInt8).null : s.to_s.to_unsafe,
      t.to_unsafe,
      Pointer(UInt8).null,
      flag_val,
      Pointer(UInt32).null
    )

    if result != 0
      Log.debug {"mount syscall failed with #{result}: #{Errno.from_value(result.abs).message} (#{source}, #{target}, #{flag_val.to_s(base: 2)})"}
    end
    result == 0
  end

  def self.mount_proc(target : Path)
    t = target.to_s
    Syscalls.mount(
      "proc".to_unsafe,
      t.to_unsafe,
      "proc".to_unsafe,
      0,
      Pointer(UInt32).null
    ) == 0
  end

  def self.unmount(path : Path) : Bool
    Syscalls.umount2(path.to_s.to_unsafe, Syscalls::MountFlags::MNT_DETACH) == 0
  end
end
