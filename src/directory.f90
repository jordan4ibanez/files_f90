module directory
  use :: string_f90
  use, intrinsic :: iso_c_binding
  implicit none


  private


  public :: directory_reader


  !* This is to be maintained as synchronous.
  !* This pipe is named as a dotfile to prevent the user from seeing this constantly opening
  !* and closing as the directory reader works.
  !* Note: This file only exists in memory.
  character(len = 30, kind = c_char), parameter :: FIFO_PIPE = ".formine_fifo_operator_hackjob"


  !* Ultra duct-taped together directory reader.
  !* We already have the tools on the system, use them.
  type :: directory_reader
    integer(c_int) :: file_count = 0
    integer(c_int) :: folder_count = 0
    type(heap_string), dimension(:), allocatable :: files
    type(heap_string), dimension(:), allocatable :: folders
  contains
    procedure :: read_directory => directory_reader_read_directory
    procedure :: destroy => directory_reader_destroy
  end type directory_reader



  !* This directly reflects the type in: [fordirent.c]
  type, bind(c) :: for_dir
    logical(c_bool) :: open_success
    integer(c_int) :: array_length
    integer(c_int) :: file_count
    integer(c_int) :: folder_count
    type(c_ptr) :: is_folder
    type(c_ptr) :: string_lengths
    type(c_ptr) :: strings
  end type for_dir


  interface


    !* Custom built upon dirent.
    !* Basically, it will
    function internal_parse_directory_folders(path) result(for_dir_pointer) bind(c, name = "parse_directory_folders")
      use, intrinsic :: iso_c_binding
      implicit none

      character(len = 1, kind = c_char), intent(in) :: path
      type(c_ptr) :: for_dir_pointer
    end function internal_parse_directory_folders


    function close_directory_folder_parse(dir_pointer) result(success) bind(c, name = "close_directory_folder_parse")
      use, intrinsic :: iso_c_binding
      implicit none

      type(c_ptr), intent(in), value :: dir_pointer
      logical(c_bool) :: success
    end function close_directory_folder_parse


  end interface


contains


  !* A helper to bind to the C code.
  !! DO NOT EXPOSE THIS FUNCTION.
  function parse_directory_folders(path) result(dir_pointer)
    use, intrinsic :: iso_c_binding
    implicit none

    character(len = *, kind = c_char), intent(in) :: path
    type(c_ptr) :: dir_pointer
    character(len = :, kind = c_char), allocatable :: c_path

    c_path = into_c_string(path)

    dir_pointer = internal_parse_directory_folders(c_path)
  end function parse_directory_folders


  !* Get all the files and folders from a directory.
  function directory_reader_read_directory(this, path) result(success)
    implicit none

    class(directory_reader), intent(inout) :: this
    character(len = *, kind = c_char), intent(in) :: path
    logical(c_bool) :: success
    type(c_ptr) :: c_for_dir_pointer
    type(for_dir), pointer :: for_dir_pointer
    integer(c_int) :: i, file_index, folder_index
    character(len = :, kind = c_char), pointer :: temp_string
    ! We have our arrays of integers and pointers which we can extract.
    logical(kind = c_bool), dimension(:), pointer :: is_folder
    integer(c_int), dimension(:), pointer :: string_lengths
    type(c_ptr), dimension(:), pointer :: c_strings

    !* Implementation note:
    !* c_for_dir_pointer and for_dir_pointer are the same memory address.
    !* This was allocated by C, it will be freed by C.

    success = .false.

    c_for_dir_pointer = parse_directory_folders(path)

    if (.not. c_associated(c_for_dir_pointer)) then
      error stop "[Directory] Error: For_dir pointer is null. ["//path//"]"
      return
    end if

    ! Grab the raw pointer into a fortran pointer.
    call c_f_pointer(c_for_dir_pointer, for_dir_pointer)

    !* You still need to free the memory. (good practice)
    if (.not. for_dir_pointer%open_success) then
      print"(A)","[Directory] Error: Failed to open path ["//path//"]"
      return
    end if

    ! The rest will error out because that means there is an implementation issue if it's ever hit.

    ! A simple assertion to ensure nothing has gone horribly wrong.
    if (for_dir_pointer%array_length /= for_dir_pointer%file_count + for_dir_pointer%folder_count) then
      error stop "[Directory] Error: Array length does not total file count plus folder count."
    end if

    ! First in the data extraction is to get the is_folder tracker.
    call c_f_pointer(for_dir_pointer%is_folder, is_folder, [for_dir_pointer%array_length])

    if (size(is_folder) /= for_dir_pointer%array_length) then
      error stop "[Directory] Error: Incorrect allocation length for is_folder."
    end if

    ! Next we extract the lengths.
    call c_f_pointer(for_dir_pointer%string_lengths, string_lengths, [for_dir_pointer%array_length])

    if (size(string_lengths) /= for_dir_pointer%array_length) then
      error stop "[Directory] Error: Incorrect allocation length for string lengths."
    end if

    ! The final move is we extract the array of strings.
    call c_f_pointer(for_dir_pointer%strings, c_strings, [for_dir_pointer%array_length])

    if (size(c_strings) /= for_dir_pointer%array_length) then
      error stop "[Directory] Error: Incorrect allocation length for C strings."
    end if

    ! We shall now pre-allocate the internal type memory with the counted number
    ! of files and folders.
    allocate(this%files(for_dir_pointer%file_count))
    allocate(this%folders(for_dir_pointer%folder_count))

    this%file_count = for_dir_pointer%file_count
    this%folder_count = for_dir_pointer%folder_count

    ! Set our indices.
    file_index = 1
    folder_index = 1

    ! Now we're going to loop through and grab all the data from these pointers.
    ! If you look at the memory addresses, they appear to be tightly packed.
    do i = 1,for_dir_pointer%array_length
      temp_string => string_from_c(c_strings(i))

      if (is_folder(i)) then
        this%folders(folder_index) = temp_string
        folder_index = folder_index + 1
      else
        this%files(file_index) = temp_string
        file_index = file_index + 1
      end if
    end do

    !? C now frees the memory.
    if (.not. close_directory_folder_parse(c_for_dir_pointer)) then
      error stop "[Directory] Error: Failed to free the C for_dir."
    end if

    success = .true.
  end function directory_reader_read_directory


  !* Deallocate the string arrays within the directory_reader and reset the counts.
  subroutine directory_reader_destroy(this)
    implicit none

    class(directory_reader), intent(inout) :: this

    ! We will allow this to overwrite itself when testing.
    if (allocated(this%files)) then
      deallocate(this%files)
    end if
    if (allocated(this%folders)) then
      deallocate(this%folders)
    end if

    this%file_count = 0
    this%folder_count = 0
  end subroutine directory_reader_destroy


end module directory
