local ffi = require("ffi")
local bit = require("bit")

--- The few POSIX calls the LuaLS tooling needs: spawning processes with pipes, waiting on file
--- descriptors, and Unix domain sockets. Linux and macOS only.
local posix = {}

ffi.cdef([[
typedef int pid_t;
typedef unsigned int mode_t;
typedef unsigned int socklen_t;
typedef long ssize_t;
typedef void (*sighandler_t)(int);

struct pollfd { int fd; short events; short revents; };
struct timespec { long tv_sec; long tv_nsec; };

extern char **environ;

int pipe(int fds[2]);
int close(int fd);
ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
int fcntl(int fd, int cmd, ...);
int open(const char *path, int flags, ...);
int unlink(const char *path);
int chmod(const char *path, mode_t mode);
int chdir(const char *path);
int access(const char *path, int mode);
char *realpath(const char *path, char *resolved);
void free(void *ptr);
char *strerror(int errnum);
pid_t getpid(void);
int kill(pid_t pid, int sig);
sighandler_t signal(int signum, sighandler_t handler);
pid_t waitpid(pid_t pid, int *status, int options);
int clock_gettime(int clock, struct timespec *tp);
struct rlimit { uint64_t rlim_cur; uint64_t rlim_max; };
int getrlimit(int resource, struct rlimit *rlim);

int socket(int domain, int type, int protocol);
int bind(int fd, const void *addr, socklen_t len);
int listen(int fd, int backlog);
int accept(int fd, void *addr, socklen_t *len);
int connect(int fd, const void *addr, socklen_t len);

int posix_spawnp(pid_t *pid, const char *file, const void *file_actions, const void *attr,
	char *const argv[], char *const envp[]);
int posix_spawn_file_actions_init(void *file_actions);
int posix_spawn_file_actions_destroy(void *file_actions);
int posix_spawn_file_actions_adddup2(void *file_actions, int fd, int new_fd);
int posix_spawnattr_init(void *attr);
int posix_spawnattr_destroy(void *attr);
int posix_spawnattr_setflags(void *attr, short flags);
int posix_spawnattr_setsigdefault(void *attr, const void *sigdefault);
int sigemptyset(void *set);
int sigaddset(void *set, int signum);
]])

---@class scripts.luals.posix.C
---@field environ ffi.cdata*
---@field pipe fun(fds: ffi.cdata*): integer
---@field close fun(fd: integer): integer
---@field read fun(fd: integer, buf: ffi.cdata*, count: integer): integer
---@field write fun(fd: integer, buf: ffi.cdata*, count: integer): integer
---@field poll fun(fds: ffi.cdata*, nfds: integer, timeout: integer): integer
---@field fcntl fun(fd: integer, cmd: integer, arg: ffi.cdata*): integer
---@field open fun(path: string, flags: integer, mode: ffi.cdata*): integer
---@field unlink fun(path: string): integer
---@field chmod fun(path: string, mode: integer): integer
---@field chdir fun(path: string): integer
---@field access fun(path: string, mode: integer): integer
---@field realpath fun(path: string, resolved: nil): ffi.cdata*
---@field free fun(ptr: ffi.cdata*)
---@field strerror fun(errnum: integer): ffi.cdata*
---@field getpid fun(): integer
---@field kill fun(pid: integer, sig: integer): integer
---@field signal fun(signum: integer, handler: ffi.cdata*): ffi.cdata*
---@field waitpid fun(pid: integer, status: ffi.cdata*, options: integer): integer
---@field clock_gettime fun(clock: integer, tp: scripts.luals.posix.Timespec): integer
---@field getrlimit fun(resource: integer, rlim: scripts.luals.posix.Rlimit): integer
---@field socket fun(domain: integer, type: integer, protocol: integer): integer
---@field bind fun(fd: integer, addr: ffi.cdata*, len: integer): integer
---@field listen fun(fd: integer, backlog: integer): integer
---@field accept fun(fd: integer, addr: nil, len: nil): integer
---@field connect fun(fd: integer, addr: ffi.cdata*, len: integer): integer
---@field posix_spawnp fun(pid: ffi.cdata*, file: string, file_actions: ffi.cdata*, attr: ffi.cdata*, argv: ffi.cdata*, envp: ffi.cdata*): integer
---@field posix_spawn_file_actions_init fun(file_actions: ffi.cdata*): integer
---@field posix_spawn_file_actions_destroy fun(file_actions: ffi.cdata*): integer
---@field posix_spawn_file_actions_adddup2 fun(file_actions: ffi.cdata*, fd: integer, new_fd: integer): integer
---@field posix_spawnattr_init fun(attr: ffi.cdata*): integer
---@field posix_spawnattr_destroy fun(attr: ffi.cdata*): integer
---@field posix_spawnattr_setflags fun(attr: ffi.cdata*, flags: integer): integer
---@field posix_spawnattr_setsigdefault fun(attr: ffi.cdata*, sigdefault: ffi.cdata*): integer
---@field sigemptyset fun(set: ffi.cdata*): integer
---@field sigaddset fun(set: ffi.cdata*, signum: integer): integer

---@class scripts.luals.posix.Timespec: ffi.cdata*
---@field tv_sec integer
---@field tv_nsec integer

---@class scripts.luals.posix.Rlimit: ffi.cdata*
---@field rlim_cur integer
---@field rlim_max integer

---@class scripts.luals.posix.Pollfd
---@field fd integer
---@field events integer
---@field revents integer

---@class scripts.luals.posix.SockaddrUn: ffi.cdata*
---@field sun_family integer
---@field sun_path ffi.cdata*

local C = ffi.C --[[@as scripts.luals.posix.C]]
local is_mac = jit.os == "OSX"

posix.POLLIN = 0x001
posix.POLLOUT = 0x004
posix.POLLERR = 0x008
posix.POLLHUP = 0x010

local EINTR = 4
local F_SETFD = 2
local FD_CLOEXEC = 1
local O_WRONLY = 1
local O_RDWR = 2
local O_CREAT = is_mac and 0x200 or 0x40
local O_APPEND = is_mac and 0x8 or 0x400
local X_OK = 1
local AF_UNIX = 1
local SOCK_STREAM = 1
local WNOHANG = 1
local SIGTERM = 15
local SIGKILL = 9
local SIGPIPE = 13
local CLOCK_MONOTONIC = is_mac and 6 or 1
local POSIX_SPAWN_SETSIGDEF = 0x04
local POSIX_SPAWN_SETSID = is_mac and 0x400 or 0x80
local RLIMIT_AS = is_mac and 5 or 9

if is_mac then
	ffi.cdef("struct rizu_sockaddr_un { uint8_t sun_len; uint8_t sun_family; char sun_path[104]; };")
else
	ffi.cdef("struct rizu_sockaddr_un { uint16_t sun_family; char sun_path[108]; };")
end

---@param name string
---@return nil
---@return string
local function failure(name)
	return nil, ("%s: %s"):format(name, ffi.string(C.strerror(ffi.errno())))
end

---@return number
function posix.now()
	local ts = ffi.new("struct timespec") --[[@as scripts.luals.posix.Timespec]]
	C.clock_gettime(CLOCK_MONOTONIC, ts)
	return tonumber(ts.tv_sec) + tonumber(ts.tv_nsec) / 1e9
end

---@param fd integer
function posix.close(fd)
	C.close(fd)
end

---@param fd integer
local function set_cloexec(fd)
	C.fcntl(fd, F_SETFD, ffi.new("int", FD_CLOEXEC))
end

--- Both ends are close-on-exec, so spawned processes only see the ends dup2'd into them.
---@return integer? read_fd
---@return integer|string write_fd_or_error
function posix.pipe()
	local fds = ffi.new("int[2]")
	if C.pipe(fds) ~= 0 then
		return failure("pipe")
	end
	set_cloexec(fds[0])
	set_cloexec(fds[1])
	return fds[0], fds[1]
end

---@param path string
---@param append boolean?
---@return integer?
---@return string?
function posix.open(path, append)
	local flags = append and bit.bor(O_WRONLY, O_CREAT, O_APPEND) or O_RDWR
	local fd = C.open(path, flags, ffi.new("int", 420)) -- 0644
	if fd < 0 then
		return failure("open " .. path)
	end
	set_cloexec(fd)
	return fd
end

--- Reads whatever is available, blocking until at least one byte or end of file.
---@param fd integer
---@param size integer?
---@return string? data empty string at end of file
---@return string? error
function posix.read(fd, size)
	size = size or 65536
	local buffer = ffi.new("char[?]", size)
	while true do
		local count = C.read(fd, buffer, size)
		if count >= 0 then
			return ffi.string(buffer, count)
		elseif ffi.errno() ~= EINTR then
			return failure("read")
		end
	end
end

---@param fd integer
---@param data string
---@return true?
---@return string?
function posix.write_all(fd, data)
	local offset = 0
	while offset < #data do
		local count = C.write(fd, ffi.cast("const char *", data) + offset, #data - offset)
		if count < 0 then
			if ffi.errno() ~= EINTR then
				return failure("write")
			end
		else
			offset = offset + tonumber(count)
		end
	end
	return true
end

--- Waits until any of `fds` is readable or hung up.
---@param fds integer[]
---@param timeout number? seconds, nil waits forever
---@return {[integer]: true} ready
function posix.poll(fds, timeout)
	---@type {[integer]: scripts.luals.posix.Pollfd}
	local entries = ffi.new("struct pollfd[?]", #fds)
	for i, fd in ipairs(fds) do
		entries[i - 1].fd = fd
		entries[i - 1].events = posix.POLLIN
	end
	local milliseconds = timeout and math.max(0, math.ceil(timeout * 1000)) or -1
	---@type {[integer]: true}
	local ready = {}
	if C.poll(entries, #fds, milliseconds) > 0 then
		for i = 0, #fds - 1 do
			if entries[i].revents ~= 0 then
				ready[entries[i].fd] = true
			end
		end
	end
	return ready
end

---@class scripts.luals.posix.SpawnOptions
---@field stdin integer?
---@field stdout integer?
---@field stderr integer?
---@field new_session boolean?

--- Starts `argv[1]`, searched on PATH. Unset streams are inherited.
---@param argv string[]
---@param options scripts.luals.posix.SpawnOptions?
---@return integer? pid
---@return string? error
function posix.spawn(argv, options)
	options = options or {}
	---@type {[integer]: ffi.cdata*?}
	local c_argv = ffi.new("char *[?]", #argv + 1)
	---@type ffi.cdata*[]
	local keep = {}
	for i, value in ipairs(argv) do
		local copy = ffi.new("char[?]", #value + 1, value)
		keep[i] = copy
		c_argv[i - 1] = copy
	end
	c_argv[#argv] = nil

	local actions = ffi.new("char[256]")
	local attr = ffi.new("char[512]")
	C.posix_spawn_file_actions_init(actions)
	C.posix_spawnattr_init(attr)
	if options.stdin then C.posix_spawn_file_actions_adddup2(actions, options.stdin, 0) end
	if options.stdout then C.posix_spawn_file_actions_adddup2(actions, options.stdout, 1) end
	if options.stderr then C.posix_spawn_file_actions_adddup2(actions, options.stderr, 2) end
	-- Children get the default SIGPIPE back, which ignore_sigpipe() would otherwise pass on.
	local default_signals = ffi.new("char[256]")
	C.sigemptyset(default_signals)
	C.sigaddset(default_signals, SIGPIPE)
	C.posix_spawnattr_setsigdefault(attr, default_signals)
	local flags = POSIX_SPAWN_SETSIGDEF
	if options.new_session then
		flags = bit.bor(flags, POSIX_SPAWN_SETSID)
	end
	C.posix_spawnattr_setflags(attr, flags)

	---@type {[0]: integer}
	local pid = ffi.new("pid_t[1]")
	local result = C.posix_spawnp(pid, argv[1], actions, attr, c_argv, C.environ)
	C.posix_spawn_file_actions_destroy(actions)
	C.posix_spawnattr_destroy(attr)
	if result ~= 0 then
		return nil, ("cannot start %s: %s"):format(argv[1], ffi.string(C.strerror(result)))
	end
	return pid[0]
end

---@param status integer
---@return integer
local function exit_code(status)
	if bit.band(status, 0x7f) == 0 then
		return bit.band(bit.rshift(status, 8), 0xff)
	end
	return 128 + bit.band(status, 0x7f)
end

---@param pid integer
---@return integer exit code, 128 + signal when killed
function posix.wait(pid)
	local status = ffi.new("int[1]")
	while C.waitpid(pid, status, 0) < 0 do
		if ffi.errno() ~= EINTR then
			return -1
		end
	end
	return exit_code(status[0])
end

---@param pid integer
---@return integer? exit code, nil while still running
function posix.try_wait(pid)
	local status = ffi.new("int[1]")
	if C.waitpid(pid, status, WNOHANG) == pid then
		return exit_code(status[0])
	end
end

--- Asks `pid` to terminate, then kills it after `grace` seconds.
---@param pid integer
---@param grace number
function posix.terminate(pid, grace)
	C.kill(pid, SIGTERM)
	local deadline = posix.now() + grace
	while posix.now() < deadline do
		if posix.try_wait(pid) then
			return
		end
		posix.poll({}, 0.05)
	end
	C.kill(pid, SIGKILL)
	posix.wait(pid)
end

--- Runs a command to completion with inherited streams.
---@param argv string[]
---@return integer? exit code
---@return string? error
function posix.run(argv)
	local pid, err = posix.spawn(argv)
	if not pid then
		return nil, err
	end
	return posix.wait(pid)
end

--- Runs a command and returns its standard output.
---@param argv string[]
---@return string? output
---@return string? error
function posix.capture(argv)
	local read_fd, write_fd = posix.pipe()
	if not read_fd then
		return nil, write_fd --[[@as string]]
	end
	---@cast write_fd integer
	local pid, err = posix.spawn(argv, {stdout = write_fd})
	C.close(write_fd)
	if not pid then
		C.close(read_fd)
		return nil, err
	end
	local chunks = {}
	while true do
		local chunk = posix.read(read_fd)
		if not chunk or chunk == "" then
			break
		end
		table.insert(chunks, chunk)
	end
	C.close(read_fd)
	local code = posix.wait(pid)
	if code ~= 0 then
		return nil, ("%s exited with status %d"):format(argv[1], code)
	end
	return table.concat(chunks)
end

--- The soft limit on this process's address space, which spawned processes inherit.
---@return number? bytes, nil when unlimited
function posix.address_space_limit()
	local limit = ffi.new("struct rlimit") --[[@as scripts.luals.posix.Rlimit]]
	if C.getrlimit(RLIMIT_AS, limit) ~= 0 or limit.rlim_cur == ffi.cast("uint64_t", -1) then
		return nil
	end
	return tonumber(limit.rlim_cur)
end

--- Makes writes to a closed pipe or socket fail with EPIPE instead of killing the process.
function posix.ignore_sigpipe()
	C.signal(SIGPIPE, ffi.cast("sighandler_t", 1)) -- SIG_IGN
end

---@return integer
function posix.getpid()
	return C.getpid()
end

---@param pid integer
---@return boolean
function posix.is_alive(pid)
	return C.kill(pid, 0) == 0
end

---@param path string
---@return string?
function posix.realpath(path)
	local resolved = C.realpath(path, nil)
	if resolved == nil then
		return nil
	end
	local result = ffi.string(resolved)
	C.free(resolved)
	return result
end

---@param path string
---@return boolean
function posix.is_executable(path)
	return C.access(path, X_OK) == 0
end

---@param path string
---@return true?
---@return string?
function posix.chdir(path)
	if C.chdir(path) ~= 0 then
		return failure("chdir " .. path)
	end
	return true
end

---@param path string
function posix.unlink(path)
	C.unlink(path)
end

---@param path string
---@return scripts.luals.posix.SockaddrUn? address
---@return string? error
local function unix_address(path)
	local address = ffi.new("struct rizu_sockaddr_un") --[[@as scripts.luals.posix.SockaddrUn]]
	if #path >= ffi.sizeof(address.sun_path) then
		return nil, "socket path too long: " .. path
	end
	address.sun_family = AF_UNIX
	ffi.copy(address.sun_path, path)
	return address
end

---@param path string
---@return integer? fd
---@return string? error
function posix.listen_unix(path)
	local address, err = unix_address(path)
	if not address then
		return nil, err
	end
	local fd = C.socket(AF_UNIX, SOCK_STREAM, 0)
	if fd < 0 then
		return failure("socket")
	end
	set_cloexec(fd)
	if C.bind(fd, address, ffi.sizeof(address) --[[@as integer]]) ~= 0 then
		err = select(2, failure("bind " .. path))
		C.close(fd)
		return nil, err
	end
	C.chmod(path, 384) -- 0600
	if C.listen(fd, 8) ~= 0 then
		err = select(2, failure("listen"))
		C.close(fd)
		return nil, err
	end
	return fd
end

---@param fd integer
---@return integer? client fd
function posix.accept(fd)
	local client = C.accept(fd, nil, nil)
	if client < 0 then
		return nil
	end
	set_cloexec(client)
	return client
end

---@param path string
---@return integer? fd
---@return string? error
function posix.connect_unix(path)
	local address, err = unix_address(path)
	if not address then
		return nil, err
	end
	local fd = C.socket(AF_UNIX, SOCK_STREAM, 0)
	if fd < 0 then
		return failure("socket")
	end
	set_cloexec(fd)
	if C.connect(fd, address, ffi.sizeof(address) --[[@as integer]]) ~= 0 then
		err = select(2, failure("connect " .. path))
		C.close(fd)
		return nil, err
	end
	return fd
end

--- Reads one `\n`-terminated line from a socket.
---@param fd integer
---@param timeout number seconds
---@return string? line without the newline
---@return string? error
function posix.read_line(fd, timeout)
	local deadline = posix.now() + timeout
	local chunks = {}
	while true do
		local remaining = deadline - posix.now()
		if remaining <= 0 or not posix.poll({fd}, remaining)[fd] then
			return nil, "timed out"
		end
		local chunk, err = posix.read(fd)
		if not chunk then
			return nil, err
		elseif chunk == "" then
			return nil, "closed"
		end
		local newline = chunk:find("\n", 1, true)
		if newline then
			table.insert(chunks, chunk:sub(1, newline - 1))
			return table.concat(chunks)
		end
		table.insert(chunks, chunk)
	end
end

return posix
