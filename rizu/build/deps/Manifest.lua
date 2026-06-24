-- Rizu Dependency Manifest

---@type rizu.build.deps.Manifest
local Manifest = {
	ffmpeg = {
		linux = {
			url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl-shared.tar.xz",
			archive = "ffmpeg-linux.tar.xz",
			dir = "ffmpeg-linux",
		},
		windows = {
			url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip",
			archive = "ffmpeg-win.zip",
			dir = "ffmpeg-win",
		},
	},
	ffmpeg_source = {
		macos = {
			url = "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n7.1.1.tar.gz",
			archive = "ffmpeg-7.1.1.tar.gz",
			dir = "ffmpeg_macos",
		},
	},
	sevenzip = {
		url = "https://www.7-zip.org/a/7z2501-src.tar.xz",
		archive = "7z2501-src.tar.xz",
		dir = "7zsdk",
	},
	love_macos = {
		url = "https://nightly.link/love2d/love/workflows/main/main/love-macos.zip",
		archive = "love-macos.zip",
	},
	love_win = {
		url = "https://nightly.link/love2d/love/workflows/main/main/love-windows-x64.zip",
		archive = "love-windows-x64.zip",
	},
	love_linux = {
		url = "https://nightly.link/love2d/love/workflows/main/main/love-linux-X64.AppImage.zip",
		archive = "love-linux-X64.AppImage.zip",
	},
	bass = {
		linux = {url = "https://www.un4seen.com/files/bass24-linux.zip", archive = "bass-linux.zip"},
		windows = {url = "https://www.un4seen.com/files/bass24.zip", archive = "bass-win.zip"},
		macos = {url = "https://www.un4seen.com/files/bass24-osx.zip", archive = "bass-macos.zip"},
	},
	bassmix = {
		linux = {url = "https://www.un4seen.com/files/bassmix24-linux.zip", archive = "bassmix-linux.zip"},
		windows = {url = "https://www.un4seen.com/files/bassmix24.zip", archive = "bassmix-win.zip"},
		macos = {url = "https://www.un4seen.com/files/bassmix24-osx.zip", archive = "bassmix-macos.zip"},
	},
	bass_fx = {
		linux = {url = "https://www.un4seen.com/files/z/0/bass_fx24-linux.zip", archive = "bass_fx-linux.zip"},
		windows = {url = "https://www.un4seen.com/files/z/0/bass_fx24.zip", archive = "bass_fx-win.zip"},
		macos = {url = "https://www.un4seen.com/files/z/0/bass_fx24-osx.zip", archive = "bass_fx-macos.zip"},
	},
	fftw_source = {
		linux = {url = "https://www.fftw.org/fftw-3.3.10.tar.gz", archive = "fftw-3.3.10.tar.gz", dir = "fftw_linux"},
		windows = {url = "https://www.fftw.org/fftw-3.3.10.tar.gz", archive = "fftw-3.3.10.tar.gz", dir = "fftw_windows"},
		macos = {url = "https://www.fftw.org/fftw-3.3.10.tar.gz", archive = "fftw-3.3.10.tar.gz", dir = "fftw_macos"},
	},
	zlib_source = {
		linux = {url = "https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz", archive = "zlib-1.3.1.tar.gz", dir = "zlib_linux"},
		windows = {url = "https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz", archive = "zlib-1.3.1.tar.gz", dir = "zlib_windows"},
		macos = {url = "https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz", archive = "zlib-1.3.1.tar.gz", dir = "zlib_macos"},
	},
	iconv_source = {
		linux = {url = "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz", archive = "libiconv-1.18.tar.gz", dir = "iconv_linux"},
		windows = {url = "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz", archive = "libiconv-1.18.tar.gz", dir = "iconv_windows"},
		macos = {url = "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz", archive = "libiconv-1.18.tar.gz", dir = "iconv_macos"},
	},
	openssl_source = {
		linux = {url = "https://github.com/openssl/openssl/archive/refs/tags/openssl-3.3.2.tar.gz", archive = "openssl-3.3.2.tar.gz", dir = "openssl_linux"},
		windows = {url = "https://github.com/openssl/openssl/archive/refs/tags/openssl-3.3.2.tar.gz", archive = "openssl-3.3.2.tar.gz", dir = "openssl_windows"},
		macos = {url = "https://github.com/openssl/openssl/archive/refs/tags/openssl-3.3.2.tar.gz", archive = "openssl-3.3.2.tar.gz", dir = "openssl_macos"},
	},
	luasec_source = {
		linux = {url = "https://github.com/lunarmodules/luasec/archive/refs/tags/v1.3.2.tar.gz", archive = "luasec-1.3.2.tar.gz", dir = "luasec_linux"},
		windows = {url = "https://github.com/lunarmodules/luasec/archive/refs/tags/v1.3.2.tar.gz", archive = "luasec-1.3.2.tar.gz", dir = "luasec_windows"},
		macos = {url = "https://github.com/lunarmodules/luasec/archive/refs/tags/v1.3.2.tar.gz", archive = "luasec-1.3.2.tar.gz", dir = "luasec_macos"},
	},
	sqlite_source = {
		linux = {url = "https://www.sqlite.org/2025/sqlite-autoconf-3490100.tar.gz", archive = "sqlite-autoconf-3490100.tar.gz", dir = "sqlite_linux"},
		windows = {url = "https://www.sqlite.org/2025/sqlite-autoconf-3490100.tar.gz", archive = "sqlite-autoconf-3490100.tar.gz", dir = "sqlite_windows"},
		macos = {url = "https://www.sqlite.org/2025/sqlite-autoconf-3490100.tar.gz", archive = "sqlite-autoconf-3490100.tar.gz", dir = "sqlite_macos"},
	},
	discord_rpc = {
		windows = {url = "https://github.com/discord/discord-rpc/releases/download/v3.4.0/discord-rpc-win.zip", archive = "discord-rpc-win.zip"},
		linux = {url = "https://github.com/discord/discord-rpc/releases/download/v3.4.0/discord-rpc-linux.zip", archive = "discord-rpc-linux.zip"},
		macos = {url = "https://github.com/discord/discord-rpc/releases/download/v3.4.0/discord-rpc-osx.zip", archive = "discord-rpc-macos.zip"},
	},
	minacalc = {
		url = "https://github.com/semyon422/minacalc-standalone",
		type = "git",
	},
	luamidi = {
		url = "https://github.com/jdeeny/lovemidi",
		type = "git",
	},
}

return Manifest
