program example
  use, intrinsic :: iso_c_binding
  use :: files_f90
  implicit none

  type(directory_reader) :: dir_reader
  type(file_reader) :: file_read
  integer(c_int) :: i

  ! This will read this project's own directory and list the files/folders.

  if (.not. dir_reader%read_directory("./")) then
    error stop
  end if

  print*,"== FOLDERS =="

  do i = 1,dir_reader%folder_count
    print*,dir_reader%folders(i)
  end do

  print*,"== FILES =="

  ! To string.
  do i = 1,dir_reader%file_count
    print*,dir_reader%files(i)
    if (.not. file_read%read_file(dir_reader%files(i)%string)) then
      error stop
    end if
    print*,file_read%file_string
    call file_read%destroy()
  end do

  ! To lines.
  do i = 1,dir_reader%file_count
    print*,dir_reader%files(i)
    if (.not. file_read%read_lines(dir_reader%files(i)%string)) then
      error stop
    end if
    print*,file_read%lines
    call file_read%destroy()
  end do

  ! Remember to close it.
  call dir_reader%destroy()

end program example
