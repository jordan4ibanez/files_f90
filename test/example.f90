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
  call reader%destroy()

end program example
