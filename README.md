# files_f90
A directory reader for Fortran.

-----

## Note:

On Windows, you will need to use MSYS2 to get POSIX ``dirent.h`` available.

-----

If you like what I do, and would like to support me: [My Patreon](https://www.patreon.com/jordan4ibanez)

-----

### Add to your project:

-----

In your fpm.toml add:

```toml
[dependencies]
files_f90 = { git = "https://github.com/jordan4ibanez/files_f90" }
```

-----

## Example:

-----

```fortran

program example
  use, intrinsic :: iso_c_binding
  use :: directory
  implicit none

  type(directory_reader) :: reader
  integer(c_int) :: i

  ! This will read this project's own directory and list the files/folders.

  call reader%read_directory("./")

  print*,"== FOLDERS =="

  do i = 1,reader%folder_count
    print*,reader%folders(i)
  end do

  print*,"== FILES =="

  do i = 1,reader%file_count
    print*,reader%files(i)
  end do

  ! Remember to close it.
  call reader%deallocate_memory()

end program example

```