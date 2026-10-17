---@meta

-- LÖVE 12.x love.filesystem API type definitions
-- Generated from LÖVE source: /home/semyon422/code/love/src/modules/filesystem/

---@alias love.filesystem.FileType "file"|"directory"|"symlink"|"other"

---@alias love.filesystem.CommonPath "appsavedir"|"appdocuments"|"userhome"|"userappdata"|"userdesktop"|"userdocuments"

---@alias love.filesystem.MountPermissions "read"|"readwrite"

---@alias love.filesystem.LoadMode "binary"|"text"|"any"

---@alias love.filesystem.FileMode "closed"|"read"|"write"|"append"

---@alias love.filesystem.FileBufferMode "none"|"line"|"full"

---File object returned by love.filesystem.openFile().
---@class love.filesystem.File
local File = {}

---Get the size of the file in bytes.
---@return number size
function File:getSize() end

---Open the file in the given mode.
---@param mode love.filesystem.FileMode
---@return boolean success
function File:open(mode) end

---Close the file.
---@return boolean success
function File:close() end

---Check if the file is open.
---@return boolean open
function File:isOpen() end

---Read data from the file.
---@param size? number Number of bytes to read. Omit for all.
---@return string|love.filesystem.FileData data, number bytes
function File:read(size) end

---Write data to the file.
---@param data string|love.Data
---@param size? number Bytes to write. Defaults to data length.
---@return boolean success
function File:write(data, size) end

---Flush buffered data to disk.
---@return boolean success
function File:flush() end

---Check if at end of file.
---@return boolean eof
function File:isEOF() end

---Get the current position in the file.
---@return number pos
function File:tell() end

---Seek to a position in the file.
---@param pos number Position to seek to.
---@return boolean success
function File:seek(pos) end

---Return an iterator that yields lines from the file.
---@return fun(): string
function File:lines() end

---Set the buffering mode for the file.
---@param mode love.filesystem.FileBufferMode
---@param size? number Buffer size in bytes.
---@return boolean success
function File:setBuffer(mode, size) end

---Get the current buffering mode and size.
---@return love.filesystem.FileBufferMode mode, number size
function File:getBuffer() end

---Get the current file mode.
---@return love.filesystem.FileMode
function File:getMode() end

---Get the filename for this File.
---@return string filename
function File:getFilename() end

---Get the file extension (without the dot).
---@return string extension
function File:getExtension() end

---FileData object representing file data.
---@class love.filesystem.FileData : love.Data
local FileData = {}

---Clone the FileData.
---@return love.filesystem.FileData
function FileData:clone() end

---Get the filename associated with this FileData.
---@return string filename
function FileData:getFilename() end

---Get the file extension (without the dot).
---@return string extension
function FileData:getExtension() end

---Native file handle for OS-level file operations.
---@class love.filesystem.NativeFile : love.filesystem.File
local NativeFile = {}

---love.filesystem module.
---@class love.filesystem
love.filesystem = {}

---Initialize the filesystem module with a directory.
---@param path string
function love.filesystem.init(path) end

---Set whether the game is running in fused mode (e.g., Android APK).
---@param fused boolean
function love.filesystem.setFused(fused) end

---Check if the game is in fused mode.
---@return boolean fused
function love.filesystem.isFused() end

---Set the identity (app name) for the save directory.
---@param ident string
---@param appendToPath? boolean
function love.filesystem.setIdentity(ident, appendToPath) end

---Get the current identity.
---@return string identity
function love.filesystem.getIdentity() end

---Set the game source directory or .love file.
---@param source string
function love.filesystem.setSource(source) end

---Get the game source path.
---@return string source
function love.filesystem.getSource() end

---Mount an archive or directory.
---@param archive string|love.Data Path to archive or Data object.
---@param mountpoint? string Mount point within virtual filesystem.
---@param appendToPath? boolean Append to search path.
---@return boolean success
function love.filesystem.mount(archive, mountpoint, appendToPath) end

---Mount a full OS path.
---@param fullpath string
---@param mountpoint string
---@param permissions? love.filesystem.MountPermissions
---@param appendToPath? boolean
---@return boolean success
function love.filesystem.mountFullPath(fullpath, mountpoint, permissions, appendToPath) end

---Mount a common system path.
---@param path love.filesystem.CommonPath
---@param mountpoint string
---@param permissions? love.filesystem.MountPermissions
---@param appendToPath? boolean
---@return boolean success
function love.filesystem.mountCommonPath(path, mountpoint, permissions, appendToPath) end

---Unmount an archive or path.
---@param archive string|love.Data Archive path or Data object.
---@return boolean success
function love.filesystem.unmount(archive) end

---Unmount a full OS path.
---@param fullpath string
---@return boolean success
function love.filesystem.unmountFullPath(fullpath) end

---Unmount a common system path.
---@param path love.filesystem.CommonPath
---@return boolean success
function love.filesystem.unmountCommonPath(path) end

---Open a file for reading or writing.
---@param filename string
---@param mode love.filesystem.FileMode
---@return love.filesystem.File file
function love.filesystem.openFile(filename, mode) end

---Open a native OS file.
---@param path string
---@param mode love.filesystem.FileMode
---@return love.filesystem.NativeFile file
function love.filesystem.openNativeFile(path, mode) end

---Create a new FileData from a file or string.
---@overload fun(filename: string): love.filesystem.FileData
---@param data string|love.Data
---@param filename string
---@return love.filesystem.FileData filedata
function love.filesystem.newFileData(data, filename) end

---Get the full path for a common path constant.
---@param path love.filesystem.CommonPath
---@return string fullpath
function love.filesystem.getFullCommonPath(path) end

---Get the current working directory.
---@return string dir
function love.filesystem.getWorkingDirectory() end

---Get the user home directory.
---@return string dir
function love.filesystem.getUserDirectory() end

---Get the APPDATA directory.
---@return string dir
function love.filesystem.getAppdataDirectory() end

---Get the save directory path.
---@return string dir
function love.filesystem.getSaveDirectory() end

---Get the directory containing the game source.
---@return string dir
function love.filesystem.getSourceBaseDirectory() end

---Get the real directory containing a file.
---@param filename string
---@return string dir
function love.filesystem.getRealDirectory(filename) end

---Canonicalize a real OS path (resolve .., ., symlinks).
---@param path string
---@return string canonical
function love.filesystem.canonicalizeRealPath(path) end

---Get the executable path.
---@return string path
function love.filesystem.getExecutablePath() end

---Check if a path exists.
---@param path string
---@return boolean exists
function love.filesystem.exists(path) end

---Get information about a file or directory.
---@param filepath string
---@param filtertype? love.filesystem.FileType Filter by type.
---@return love.filesystem.FileType type, boolean readonly, number? size, number? modtime
function love.filesystem.getInfo(filepath, filtertype) end

---Create a directory.
---@param dir string
---@return boolean success
function love.filesystem.createDirectory(dir) end

---Remove a file or directory.
---@param file string
---@return boolean success
function love.filesystem.remove(file) end

---Read the contents of a file.
---@overload fun(filename: string): string, number
---@param filename string
---@param container "string"|"data"
---@param size? number Bytes to read. -1 or omit for all.
---@return string|love.Data data, number bytes
function love.filesystem.read(filename, container, size) end

---Write data to a file (overwrites).
---@overload fun(filename: string, data: string|love.Data, size?: number): boolean
---@param filename string
---@param data string|love.Data
---@param size? number Bytes to write. Defaults to data length.
---@return boolean success
function love.filesystem.write(filename, data, size) end

---Append data to a file.
---@overload fun(filename: string, data: string|love.Data, size?: number): boolean
---@param filename string
---@param data string|love.Data
---@param size? number Bytes to append. Defaults to data length.
---@return boolean success
function love.filesystem.append(filename, data, size) end

---Get a table of items in a directory.
---@param dir string
---@return string[] items
function love.filesystem.getDirectoryItems(dir) end

---Return an iterator that yields lines from a file.
---@param filename string
---@return fun(): string
function love.filesystem.lines(filename) end

---Load a Lua chunk from a file without running it.
---@param filename string
---@param mode? love.filesystem.LoadMode
---@return function chunk
function love.filesystem.load(filename, mode) end

---Enable or disable symbolic link support.
---@param enable boolean
function love.filesystem.setSymlinksEnabled(enable) end

---Check if symbolic links are enabled.
---@return boolean enabled
function love.filesystem.areSymlinksEnabled() end

---Get the require path as a string.
---@return string path
function love.filesystem.getRequirePath() end

---Set the require path (semicolon-separated).
---@param path string
function love.filesystem.setRequirePath(path) end

---Get the C require path as a string.
---@return string path
function love.filesystem.getCRequirePath() end

---Set the C require path (semicolon-separated).
---@param path string
function love.filesystem.setCRequirePath(path) end

---Deprecated: use openFile instead.
---@param filename string
---@param mode? love.filesystem.FileMode
---@return love.filesystem.File file
function love.filesystem.newFile(filename, mode) end
