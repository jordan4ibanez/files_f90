!* To keep file io synchronous, only use this library to work with files.
module files_f90
  use :: string_f90
  use :: directory
  use, intrinsic :: iso_c_binding
  implicit none


  private


  public :: file_reader
  public :: directory_reader


  !* This is your basic (file -> allocated string) reader. I think it's pretty neat. :)
  type :: file_reader
    ! Straight shot component.
    character(len = :), allocatable :: file_string
    ! By line components.
    type(heap_string), dimension(:), allocatable :: lines
    integer(c_int) :: line_count = 0
  contains
    procedure :: read_file => file_reader_read_file
    procedure :: read_lines => file_reader_read_file_into_lines
    procedure :: destroy => file_reader_destroy
  end type file_reader


contains


  !* Open a file, read it into a string, close the file, returns success.
  function file_reader_read_file(this, file_path) result(success)
    implicit none

    class(file_reader), intent(inout) :: this
    character(len = *, kind = c_char), intent(in) :: file_path
    logical(c_bool) :: success
    integer(c_int) :: file_io_identifier
    integer(c_int) :: file_size
    logical :: exists

    ! First we check if the file exists.
    inquire(file = file_path, exist = exists, size = file_size)

    ! If the file does not exist, we're not going to attempt to allocate anything.
    if (exists) then

      ! We want readonly access and streaming of the data into a string.
      open(newunit = file_io_identifier, file = file_path, status = "old", action = "read", access = "stream")

      ! Now allocate the size of the string.
      allocate(character(len = file_size, kind = c_char) :: this%file_string)

      ! And finally stream it into the string.
      read(file_io_identifier) this%file_string

      ! Now we must close it so there is not an IO leak.
      close(file_io_identifier)

      success = .true.
    else
      ! print"(A)","[Files] Error: File path ["//file_path//"] does not exist."
      success = .false.
    end if
  end function file_reader_read_file


  !* Read a file into an array of heap_strings. Returns success.
  function file_reader_read_file_into_lines(this, file_path) result(success)
    use :: forray, only: array_string_insert
    implicit none

    class(file_reader), intent(inout) :: this
    character(len = *, kind = c_char), intent(in) :: file_path
    logical(c_bool) :: success
    !! This is testing debugging
    character(len = :, kind = c_char), allocatable :: temporary_container
    integer(c_int) :: found_newline_index
    integer(c_int) :: length_of_buffer
    type(heap_string), dimension(:), allocatable :: temp_string_array

    ! I can't figure out how to make the io operation read line by line so we're going to
    ! use the internal file_string component as a temp buffer.

    success = .false.

    ! Push the entire string buffer into this.
    ! If the file does not exist, we're not going to attempt to do anything.
    if (.not. this%read_file(file_path)) then
      return
    end if

    ! Start off with nothing.
    allocate(this%lines(0))

    ! This should literally be unable to get stuck in an infinite loop.
    do while(.true.)

      ! Sniff out that \n.
      found_newline_index = index(this%file_string, achar(10))

      if (found_newline_index == 0) then
        ! When we reached the end with no \n, we need specific handling of this.
        ! Basically, just dump the final line in.

        ! Tick up the number of lines.
        this%line_count = this%line_count + 1
        ! Dump it in.
        temp_string_array = array_string_insert(this%lines, heap_string(this%file_string))
        call move_alloc(temp_string_array, this%lines)
        ! And remove residual memory.
        deallocate(this%file_string)
        exit
      else
        ! Tick up the number of lines.
        this%line_count = this%line_count + 1
        ! We're just going to continuously roll a bigger array with new elements.
        temporary_container = this%file_string(1:found_newline_index - 1)
        ! Append it.
        temp_string_array = array_string_insert(this%lines, heap_string(temporary_container))
        call move_alloc(temp_string_array, this%lines)
        ! Find the new total length of the string buffer.
        length_of_buffer = len(this%file_string)
        ! Step it over the \n and cut out the beginning.
        this%file_string = this%file_string(found_newline_index + 1:length_of_buffer)
      end if
    end do

    success = .true.
  end function file_reader_read_file_into_lines


  subroutine file_reader_destroy(this)
    implicit none

    class(file_reader), intent(inout) :: this
    integer(c_int32_t) :: i

    if (allocated(this%file_string)) then
      deallocate(this%file_string)
    end if

    if (allocated(this%lines)) then
      do i = 1,this%line_count
        if (allocated(this%lines(i)%string)) then
          deallocate(this%lines(i)%string)
        end if
      end do
      deallocate(this%lines)
      this%line_count = 0
    end if
  end subroutine file_reader_destroy


end module files_f90
