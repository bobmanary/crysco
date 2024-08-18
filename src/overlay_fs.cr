require "./syscalls"
require "file_utils"


module Crysco::OverlayFs
  # The Linux overlay filesystem allows us to use a provided directory
  # (or a stack of multiple directories) as a read-only base with a
  # writable directory layered on top of it.
  # See https://docs.kernel.org/filesystems/overlayfs.html
  def self.mount_overlay(lower_path : Path, hostname : String) : Path | Nil
    # set up working dirs and the target mountpoint
    upper_path = Path["/tmp", hostname, "upper"]
    work_path = Path["/tmp", hostname, "work"]
    target_path = Path["/tmp", hostname, "target"]
    Dir.mkdir_p(upper_path)
    Dir.mkdir_p(work_path)
    Dir.mkdir_p(target_path)

    # escape separators used in mount options
    lowerdir = lower_path.to_s.gsub(/[:=,]/, "\\\\\\0")

    # other directory names should not need escaping unless hostname is funky
    upperdir = upper_path.to_s
    workdir = work_path.to_s
    target = target_path.to_s

    mount_options = "lowerdir=#{lowerdir},upperdir=#{upperdir},workdir=#{workdir}"

    Log.debug {"overlayfs mount options: #{mount_options}"}

    unless Syscalls.mount(
      "overlay".to_unsafe,
      target.to_unsafe,
      "overlay".to_unsafe,
      0u32,
      mount_options.to_unsafe
    ) == 0
      return nil
    end

    target_path
  end

  def self.unmount(hostname : String) : Bool
    cdir = Path["/tmp", hostname]
    target_path = cdir / "target"

    unless Syscalls.umount2(target_path.to_s.to_unsafe, Syscalls::MountFlags::MNT_DETACH) == 0
      return false
    end

    FileUtils.rm_rf(cdir)

    true
  end
end
