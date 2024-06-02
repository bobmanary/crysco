require "lib_c"

lib Linux
  fun sethostname(name : LibC::Char*, len : LibC::SizeT) : LibC::Int
  fun setgroups(n : LibC::SizeT, groups : LibC::GidT*) : LibC::Int
  fun setresgid(real_gid : LibC::GidT, effective_gid : LibC::GidT, savedset_gid : LibC::GidT) : LibC::Int
  fun setresuid(real_uid : LibC::UidT, effective_uid : LibC::UidT, savedset_uid : LibC::UidT) : LibC::Int
end
