-- Rizu Dependency Manifest
return {
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
		-- MacOS SDK is handled by setup_cross_macos.sh due to its proprietary nature
	},
	sevenzip = {
		url = "https://www.7-zip.org/a/7z2409-src.7z",
		archive = "7z-src.7z",
		dir = "7zsdk",
	},
	love_macos = {
		url = "https://github.com/love2d/love/releases/download/11.5/love-11.5-macos.zip",
		archive = "love-macos.zip",
	},
	love_win = {
		url = "https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip",
		archive = "love-win.zip",
	},
	love_linux = {
		url = "https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage",
		archive = "love-linux.AppImage",
	},
	rtmidi = {
		linux = {url = "https://github.com/thestk/rtmidi/archive/refs/tags/v6.0.0.tar.gz", archive = "rtmidi-linux.tar.gz"},
		windows = {url = "https://github.com/thestk/rtmidi/archive/refs/tags/v6.0.0.tar.gz", archive = "rtmidi-win.tar.gz"},
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
	bassopus = {
		linux = {url = "https://www.un4seen.com/files/bassopus24-linux.zip", archive = "bassopus-linux.zip"},
		windows = {url = "https://www.un4seen.com/files/bassopus24.zip", archive = "bassopus-win.zip"},
		macos = {url = "https://www.un4seen.com/files/bassopus24-osx.zip", archive = "bassopus-macos.zip"},
	},
	fftw = {
		-- Optional: old upstream URL is no longer reliable.
		-- Keep runtime dlls from repo or add a maintained mirror when needed.
		-- windows = {url = "...", archive = "fftw-win.zip"},
	},
	fftw_source = {
		linux = {url = "https://www.fftw.org/fftw-3.3.10.tar.gz", archive = "fftw-3.3.10.tar.gz", dir = "fftw_linux"},
	},
	zlib_source = {
		linux = {url = "https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz", archive = "zlib-1.3.1.tar.gz", dir = "zlib_linux"},
		windows = {url = "https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz", archive = "zlib-1.3.1.tar.gz", dir = "zlib_windows"},
	},
	iconv_source = {
		linux = {url = "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz", archive = "libiconv-1.18.tar.gz", dir = "iconv_linux"},
		windows = {url = "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.18.tar.gz", archive = "libiconv-1.18.tar.gz", dir = "iconv_windows"},
	},
	openssl_source = {
		linux = {url = "https://github.com/openssl/openssl/archive/refs/tags/openssl-3.3.2.tar.gz", archive = "openssl-3.3.2.tar.gz", dir = "openssl_linux"},
		windows = {url = "https://github.com/openssl/openssl/archive/refs/tags/openssl-3.3.2.tar.gz", archive = "openssl-3.3.2.tar.gz", dir = "openssl_windows"},
	},
	luasec_source = {
		linux = {url = "https://github.com/lunarmodules/luasec/archive/refs/tags/v1.3.2.tar.gz", archive = "luasec-1.3.2.tar.gz", dir = "luasec_linux"},
		windows = {url = "https://github.com/lunarmodules/luasec/archive/refs/tags/v1.3.2.tar.gz", archive = "luasec-1.3.2.tar.gz", dir = "luasec_windows"},
	},
	sqlite = {
		-- Optional: versioned sqlite.org links expire.
		-- Keep runtime dlls from repo or pin to a current yearly URL.
		-- windows = {url = "...", archive = "sqlite-win.zip"},
	},
	sqlite_source = {
		linux = {url = "https://www.sqlite.org/2025/sqlite-autoconf-3490100.tar.gz", archive = "sqlite-autoconf-3490100.tar.gz", dir = "sqlite_linux"},
	},
	discord_rpc = {
		windows = {url = "https://github.com/discord/discord-rpc/releases/download/v3.4.0/discord-rpc-win.zip", archive = "discord-rpc-win.zip"},
		linux = {url = "https://github.com/discord/discord-rpc/releases/download/v3.4.0/discord-rpc-linux.zip", archive = "discord-rpc-linux.zip"},
		macos = {url = "https://github.com/discord/discord-rpc/releases/download/v3.4.0/discord-rpc-osx.zip", archive = "discord-rpc-macos.zip"},
	},
	prebuilt_bins = {
		macos = {
			{url = "https://dl.rizu.su/bin/mac64/libiconv.dylib", name = "libiconv.dylib"},
			{url = "https://dl.rizu.su/bin/mac64/libz.dylib", name = "libz.dylib"},
			{url = "https://dl.rizu.su/bin/mac64/ssl.dylib", name = "ssl.dylib", local_path = "3rd-deps/lib/ssl.dylib"},
		},
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
