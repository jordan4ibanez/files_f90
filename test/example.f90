program example
  use, intrinsic :: iso_c_binding
  use :: files_f90
  implicit none

  type(directory_reader) :: reader
  type(file_reader) :: file_read
  integer(c_int) :: i

  ! This will read this project's own directory and list the files/folders.

  call reader%read_directory("./")

  print*,"== FOLDERS =="

  do i = 1,reader%folder_count
    print*,reader%folders(i)
  end do

  print*,"== FILES =="

  ! To string.
  do i = 1,reader%file_count
    print*,reader%files(i)
    call file_read%read_file(reader%files(i)%string)
    print*,file_read%file_string
    call file_read%destroy()
  end do

  ! To lines.
  do i = 1,reader%file_count
    print*,reader%files(i)
    call file_read%read_lines(reader%files(i)%string)
    print*,file_read%lines
    call file_read%destroy()
  end do

  ! Remember to close it.
  call reader%destroy()

end program example
