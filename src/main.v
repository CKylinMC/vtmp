module main

import os
import cli
import time
import clipboard

enum Action{
	nothing
	open_in_term
	open_in_explorer
}

const base62_st = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

fn str_index(s string, c string) i64 {
	for i, v in s {
		if v.str() == c {
			return i
		}
	}
	return -1
}

fn base62(source i64) string {
	mut rst := ''
	size := base62_st.len
	mut src := source
	mut negative := false
	if source < 0 {
		src = -source
		negative = true
	}
	for {
		a := i64(src) % size
		rst = base62_st[a..a + 1] + rst
		src = src / size
		if src <= 0 {
			break
		}
	}
	if negative {
		return '-' + rst
	} else {
		return rst
	}
}

fn debase62(encoded string) i64 {
	mut rst := i64(0)
	mut negative := false
	mut src := encoded
	size := base62_st.len
	if src.starts_with('-') {
		src = src[1..]
		negative = true
	}
	for _, v in src {
		a := str_index(base62_st, v.str())
		if a < 0 {
			continue
		}
		rst = rst * size + a
	}
	if negative {
		return -rst
	} else {
		return rst
	}
}

fn get_tmp_base_dir() string {
	if os.getenv('VTMP_DIR') != '' {
		basepath := os.real_path(os.getenv('VTMP_DIR'))
		if !os.exists(basepath) {
			os.mkdir_all(basepath) or {
				println('Failed to create VTMP_DIR: ' + basepath)
				exit(1)
			}
		}
		return basepath
	} else {
		return os.getenv('TEMP')
	}
}

fn get_today_code(nowtime time.Time) string {
	datei64 :=
	    nowtime.day
		+ nowtime.month  * 100
		+ nowtime.year   * 10000
	return base62(datei64)
}

fn get_time_code(nowtime time.Time) string {
	timei64 :=
		nowtime.second
		+ nowtime.minute * 100
		+ nowtime.hour   * 10000
	return base62(timei64)
}

fn time_based_base62() string {
	nowtime := time.now()
	return get_today_code(nowtime) + get_time_code(nowtime)
}

fn get_dir_prefix() string {
	if os.getenv('VTMP_DIR_NO_PREFIX') == '1' {
		return ''
	} else if os.getenv('VTMP_DIR_PREFIX') != '' {
		return os.getenv('VTMP_DIR_PREFIX')
	} else {
		return 'vtmp_'
	}
}

fn get_random_dir_name() string {
	return get_dir_prefix() + time_based_base62()
}

fn get_new_random_dir_path() string {
	return os.join_path(get_tmp_base_dir(), get_random_dir_name())
}

fn remember_last_tmp_dir(dirname string) {
	if os.getenv('VTMP_NO_REMEMBER') == '1' {
		return
	}
	rememberfile := os.join_path(get_tmp_base_dir(), 'vtmp_last_dir')
	if os.exists(rememberfile) {
		os.rm(rememberfile) or {
			println('Failed to remove save file: ' + rememberfile)
			exit(1)
		}
	}
	os.write_file(rememberfile, dirname) or {
		println('Failed to remember last tmp dir: ' + dirname)
		exit(1)
	}
}

fn unremember_last_tmp_dir() {
	if os.getenv('VTMP_NO_REMEMBER') == '1' {
		return
	}
	rememberfile := os.join_path(get_tmp_base_dir(), 'vtmp_last_dir')
	if os.exists(rememberfile) {
		os.rm(rememberfile) or {
			println('Failed to remove save file: ' + rememberfile)
			exit(1)
		}
	}
}

fn create_new_tmp_dir() (string, string) {
	dirname := get_random_dir_name()
	return create_new_tmp_dir_with_name(dirname)
}

fn create_new_tmp_dir_with_name(dirname string) (string, string) {
	tmpbase := get_tmp_base_dir()
	dirpath := os.join_path(tmpbase, dirname)
	if !os.exists(dirpath) {
		os.mkdir_all(dirpath) or {
			println('Failed to create tmp dir: ' + dirpath)
			exit(1)
		}
	}
	remember_last_tmp_dir(dirname)
	return dirpath, dirname
}

fn get_last_tmp_dir() string {
	rememberfile := os.join_path(get_tmp_base_dir(), 'vtmp_last_dir')
	if !os.exists(rememberfile) {
		return ''
	}
	return os.read_file(rememberfile) or { '' }
}

fn remove_dir(dirname string) {
	tmpbase := get_tmp_base_dir()
	dirpath := os.join_path(tmpbase, dirname)
	if os.exists(dirpath) {
		os.rmdir_all(dirpath) or {
			println('Failed to remove tmp dir: ' + dirname)
			exit(1)
		}
	}
}

fn open_tmp_dir(clear bool, then Action) {
	dirpath, dirname := create_new_tmp_dir()
	defer {
		if clear {
			remove_dir(dirname)
			unremember_last_tmp_dir()
			println('Removed tmp dir: ' + dirname)
		}
	}
	println('Created tmp dir: ' + dirname)
	open_dir(dirpath, dirname, clear, then)
}

fn open_dir(dirpath string, dirname string, clear bool, then Action) {
	if clear {
		println('Folder will be removed after you close the terminal.')
	} else {
		println('Remember to remove the folder after you finish.')
	}
	match then {
		.open_in_term {
			os.execvp('cmd', ['/k', 'cd', '/d', os.quoted_path(os.real_path(dirpath))]) or {
				println('Failed to open tmp dir: ' + dirpath)
			}
		}
		.open_in_explorer {
			os.execvp('explorer', [os.quoted_path(os.real_path(dirpath))]) or {
				println('Failed to open tmp dir: ' + dirpath)
			}
		}
		else {}
	}
	os.execvp('cmd', ['/k', 'cd', '/d', os.quoted_path(os.real_path(dirpath))]) or {
		println('Failed to open tmp dir: ' + dirpath)
	}
}

fn list_today_tmp_dirs() {
	tmpbase := get_tmp_base_dir()
	mut dirs := []string{}
	entries := os.ls(tmpbase) or { [] }

	prefix := get_dir_prefix()get_today_code(time.now())

	for entry in entries {
		if os.is_dir(os.join_path(tmpbase, entry)) {
			if entry.starts_with(prefix) {
				dirs << entry
			}
		}
	}

	if dirs.len == 0 {
		println('No tmp dir found today.')
		return
	} else {
		println('Today\'s tmp dirs:')
		for dir in dirs {
			println('  ' + dir)
		}
	}
}

fn list_all_tmp_dirs() {
	tmpbase := get_tmp_base_dir()
	mut dirs := []string{}
	entries := os.ls(tmpbase) or { [] }

	prefix := get_dir_prefix()get_today_code(time.now())

	for entry in entries {
		if os.is_dir(os.join_path(tmpbase, entry)) {
			if entry.starts_with(prefix) {
				dirs << entry
			}
		}
	}

	if dirs.len == 0 {
		println('No tmp dir found today.')
		return
	} else {
		println('All found tmp dirs:')
		for dir in dirs {
			println('  ' + dir)
		}
	}
}

fn copy_string(str string){
	mut c:=clipboard.new()
	c.copy(str)
	defer {
		c.destroy()
	}
}

fn main() {
	mut app := cli.Command{
		name:        'vtmp'
		description: 'Fast and simple temporary directory manager.\n\nRun withou any arguments to create a new temporary directory and auto-remove after close.\n\nAvailable Environment Variables:\n  VTMP_DIR\t\tSpecify a path to store all temporary folders. Default is System Temp Path.\n  VTMP_DIR_PREFIX\tSpecify a prefix name to create next tmp folder.\n  VTMP_DIR_NO_PREFIX\tDisable prefix when creating tmp folder (not recommended)\n  VTMP_NO_REMEMBER\tDisable "last" feature.'
		execute:     fn (cmd cli.Command) ! {
			open_tmp_dir(true, .open_in_term)
		}
		commands: [
			cli.Command{
				name: 'list'
				description: 'List all temporary directories'
				execute: fn (cmd cli.Command) ! {
					list_all_tmp_dirs()
				}
			}
			cli.Command{
				name: 'today'
				description: 'List all temporary directories created today'
				execute: fn (cmd cli.Command) ! {
					list_today_tmp_dirs()
				}
			}
			cli.Command{
				name: 'new'
				description: 'Create a new temporary directory with a given name'
				required_args: 1
				flags: [
					cli.Flag{
						name: 'open'
						abbrev: 'o'
						description: 'Open the directory in explorer'
					}
					cli.Flag{
						name: 'term'
						abbrev: 't'
						description: 'Open the directory in terminal'
					}
					cli.Flag{
						name: 'copy'
						abbrev: 'c'
						description: 'Copy the directory path to clipboard'
					}
					cli.Flag{
						name: 'remove'
						abbrev: 'r'
						description: 'Remove the directory after close'
					}
				]
				execute: fn(cmd cli.Command)!{
					dirpath, dirname := create_new_tmp_dir_with_name(cmd.args[0])
					println('Created tmp dir: ' + dirpath)
					remove := cmd.flags.get_bool('remove') or { false }
					if cmd.flags.get_bool('open') or { false } {
						open_dir(dirpath, dirname, remove, .open_in_explorer)
					} else if cmd.flags.get_bool('term') or { false } {
						open_dir(dirpath, dirname, remove, .open_in_term)
					} else if cmd.flags.get_bool('copy') or { false } {
						copy_string(dirpath)
						println('Copied tmp dir path to clipboard: ' + dirpath)
						if remove {
							println("You need to remove the folder manually.")
						}
					}
				}
			}
			cli.Command{
				name: 'term'
				execute: fn (cmd cli.Command) ! {
					open_tmp_dir(false, .open_in_term)
				}
				description: 'Open a new temporary directory in terminal'
			}
			cli.Command{
				name: 'open'
				execute: fn(cmd cli.Command)!{
					open_tmp_dir(false, .open_in_explorer)
				}
				description: 'Open a new temporary directory in explorer'
			}
			cli.Command{
				name: 'copy'
				execute: fn(cmd cli.Command)!{
					dirpath, _ := create_new_tmp_dir()
					copy_string(dirpath)
					println('Copied tmp dir path to clipboard: ' + dirpath)
				}
				description: 'Copy the path of a new temporary directory to clipboard'
			}
			cli.Command{
				name: 'last'
				description: 'Show the path of the last temporary directory. Run without any arguments to open the last temporary directory in terminal and remove it after close.'
				pre_execute: fn(cmd cli.Command)!{
					if os.getenv('VTMP_NO_REMEMBER') == '1' {
						println('Remembering is disabled.')
						exit(1)
					}
				}
				execute: fn(cmd cli.Command)!{
					last_dir := get_last_tmp_dir()
					if last_dir == '' {
						println('No tmp dir remembered.')
						return
					}
					println('Last tmp dir: ' + last_dir)
					open_dir(os.join_path(get_tmp_base_dir(), last_dir), last_dir, true, .open_in_term)
				}
				commands: [
					cli.Command{
						name: 'term'
						description: 'Open the last temporary directory in terminal'
						execute: fn (cmd cli.Command) ! {
							last_dir := get_last_tmp_dir()
							if last_dir == '' {
								println('No tmp dir remembered.')
								return
							}
							println('Last tmp dir: ' + last_dir)
							open_dir(os.join_path(get_tmp_base_dir(), last_dir), last_dir, false, .open_in_term)
						}
					}
					cli.Command{
						name: 'open'
						description: 'Open the last temporary directory in explorer'
						execute: fn(cmd cli.Command)!{
							last_dir := get_last_tmp_dir()
							if last_dir == '' {
								println('No tmp dir remembered.')
								return
							}
							println('Last tmp dir: ' + last_dir)
							open_dir(os.join_path(get_tmp_base_dir(), last_dir), last_dir, false, .open_in_explorer)
						}
					}
					cli.Command{
						name: 'copy'
						description: 'Copy the path of the last temporary directory to clipboard'
						execute: fn(cmd cli.Command)!{
							last_dir := get_last_tmp_dir()
							if last_dir == '' {
								println('No tmp dir remembered.')
								return
							}
							copy_string(os.join_path(get_tmp_base_dir(), last_dir))
							println('Copied tmp dir path to clipboard: ' + last_dir)
						}
					}
					cli.Command{
						name: 'clear'
						description: 'Remove the last temporary directory'
						execute: fn(cmd cli.Command)!{
							last_dir := get_last_tmp_dir()
							if last_dir == '' {
								println('No tmp dir to clear.')
								return
							}
							remove_dir(last_dir)
							unremember_last_tmp_dir()
							println('Removed tmp dir: ' + last_dir)
						}
					}
				]
			}
		]
	}
	app.setup()
	app.parse(os.args)
}
