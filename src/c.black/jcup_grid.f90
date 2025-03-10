!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+

!
!Copyright (c) 2011, arakawa@rist.jp
!All rights reserved.
!
module jcup_pe_array
  private

  public :: single_pe_array_type
  public :: pe_array_type
  public :: init_pe_array
  public :: write_pe_array_info

  type single_pe_array_type
    integer :: pe_num ! pe number of local component
    integer :: s_point, e_point
#ifdef EXCHANGE_BY_MPI_RMA
    integer :: s_point_send
    integer :: e_point_send
#endif
  end type

  type pe_array_type
    integer :: num_of_pe
    integer :: num_of_point
    integer :: num_of_data ! number of send, recv data
    type(single_pe_array_type), pointer :: pa(:)
    integer, pointer :: data_point(:)
    integer, pointer :: data_index(:)
    real(kind=8), pointer :: data_buffer(:) ! num_of_send_recv_data_point x num_of_data
#ifdef EXCHANGE_BY_MPI_RMA
    integer :: send_buffer_size
#endif
  end type

contains

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine init_pe_array(pe_array)
  implicit none
  type(pe_array_type), intent(INOUT) :: pe_array

  pe_array%num_of_pe = 0 
  pe_array%num_of_point = 0
  pe_array%num_of_data = 0

  pe_array%pa => NULL()
  pe_array%data_point => NULL()
  pe_array%data_index => NULL()
  pe_array%data_buffer => NULL()

end subroutine init_pe_array

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine write_pe_array_info(unit, pe_array)
  implicit none
  integer, intent(in) :: unit
  type(pe_array_type), intent(IN) :: pe_array
  integer :: i

  write(unit, '("NUM of PE = ",I2,", NUM of POINT = ",I4,", NUM of DATA = ",I4)') &
                                  pe_array%num_of_pe, pe_array%num_of_point, pe_array%num_of_data
  write(unit, '(A7,A9,A9)') "PE NUM",", S POINT",", E POINT " 

  do i = 1, pe_array%num_of_pe
    write(unit, '(I7,I9,I9)') pe_array%pa(i)%pe_num, pe_array%pa(i)%s_point, pe_array%pa(i)%e_point
  end do

end subroutine write_pe_array_info

!=======+=========+=========+=========+=========+=========+=========+=========+

end module jcup_pe_array

!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+


module jcup_exchange_grid

  private

  public :: exchange_grid_type
  public :: init_exchange_grid

  type exchange_grid_type
    real(kind=8), pointer :: send_double_buffer_1d(:,:)

    integer          :: num_of_my_send_point             ! array size of my send point
    integer          :: num_of_my_recv_point             ! array size of my recv point
    integer, pointer :: global_index_of_my_send_point(:) ! global index of my local send point
    integer, pointer :: global_index_of_my_recv_point(:) ! global index of my local recv point
    integer, pointer :: local_operation_index(:)         ! global operation index of my local operation
    integer, pointer :: local_send_grid_index(:)         ! global send point index of my local operation
    integer, pointer :: local_recv_grid_index(:)         ! global recv point index of my local operation
    integer, pointer :: send_index_converter(:)          ! mapping table from operation index to send grid index
    integer, pointer :: recv_index_converter(:)          ! mapping table from operation index to recv grid index
    integer, pointer :: remapped_send_index(:)           ! remapped send index table from send index converter
 
    integer, pointer :: local_index(:) ! local grid index of my local operation
    integer, pointer :: local_send_index(:)

  end type



contains

subroutine init_exchange_grid(e_grid)
  implicit none
  type(exchange_grid_type), intent(INOUT) :: e_grid
  
  e_grid%num_of_my_send_point = 0
  e_grid%num_of_my_recv_point = 0
  e_grid%send_double_buffer_1d => NULL()
  e_grid%global_index_of_my_send_point => NULL()
  e_grid%global_index_of_my_recv_point => NULL()
  e_grid%local_operation_index => NULL()
  e_grid%local_send_grid_index => NULL()
  e_grid%local_recv_grid_index => NULL()
  e_grid%send_index_converter => NULL()
  e_grid%recv_index_converter => NULL()
  e_grid%remapped_send_index => NULL()
  e_grid%local_index => NULL()
  e_grid%local_send_index => NULL()

end subroutine init_exchange_grid

end module jcup_exchange_grid


!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+

module jcup_grid
  use jcup_constant, only : NUM_OF_EXCHANGE_DATA, NUM_OF_EXCHANGE_GRID, MAX_MODEL, MAX_GRID, STR_SHORT
  use jcup_pe_array, only : pe_array_type
  use jcup_exchange_grid, only : exchange_grid_type

  private

!--------------------------------   public  ----------------------------------!

  public :: init_grid
  public :: destruct_grid
  public :: def_grid
  public :: end_def
  public :: GetNumOfMyGrid
  public :: get_my_grid_num ! integer function (grid_name)
  public :: set_grid
  public :: is_my_grid ! logical function (grid_name)
  public :: get_operation_index ! subroutine (my_comp_name, send_comp_name, mapping_tag, num_of_operation, operation_index)
  public :: get_send_grid_index 
  ! subroutine (my_comp_name, send_comp_name, mapping_tag, num_of_send_grid_point, send_grid_index) 
  public :: get_recv_grid_index
  ! subroutine (my_comp_name, send_comp_name, mapping_tag, num_of_recv_grid_point, recv_grid_index) 
  public :: get_interpolation_index
  public :: set_grid_mapping_1d
  public :: set_grid_mapping_1d_local ! subroutine ! 2016/12/27 [NEW]
  public :: exchange_grid_mapping  ! subroutine (send_comp_id, recv_comp_id, mapping_tag)
  public :: send_grid_mapping      ! subroutine (send_comp_id, recv_comp_id, mapping_tag)
  public :: recv_grid_mapping      ! subroutine (send_comp_id, recv_comp_id, mapping_tag)
  public :: finish_grid_mapping
  public :: write_grid_mapping_info
  public :: set_data
  public :: get_data     ! subroutine (recv_comp_id, send_comp_id, mapping_tag, data, num_of_data)
  public :: send_data_1d ! subroutine (send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data)
  public :: recv_data_1d ! subroutine (recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data)
  public :: get_send_data_buffer_size ! integer function(send_comp_id, recv_comp_id, mapping_tag) ! 2018/07/23 for jpl nowait send
  public :: send_data_1d_nowait ! subroutine (send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data) ! 2018/07/05 for jpl
  public :: recv_data    ! subroutine (recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data)
  public :: recv_data_nowait    ! subroutine (recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data) ! 2018/07/05 for jpl
  public :: send_recv_waitall   ! subroutine ()  ! 20180705 for jpl
  public :: exchange_data_comp

  public :: interpolate_data_1d
  public :: get_data_double_1d

#ifdef EXCHANGE_BY_MPI_RMA
  public :: init_mpi_rma
  public :: finalize_mpi_rma
#endif

!--------------------------------   private  ---------------------------------!



  logical, private :: is_InitGrid=.false.

  type all_array_type 
      type(pe_array_type), pointer :: pe_array(:)   ! array size is a number of interpolation pattern
  end type

  type(all_array_type), pointer :: send_array(:,:) ! array of recv components (my_component_id, recv_component_id)
  type(all_array_type), pointer :: recv_array(:,:) ! array of send components (my_component_id, send_component_id)

  type(pe_array_type), pointer :: spa ! current send pe array 
  type(pe_array_type), pointer :: rpa ! current send pe array 

  type all_grid_type
    type(exchange_grid_type), pointer :: ex_grid(:) ! size : EXCHANGE_GRID
  end type

  type(all_grid_type), pointer :: a_grid(:,:) ! array of exchange grid (my_component_id, target_component_id)
  type(exchange_grid_type), pointer :: peg ! pointer of current exchange grid

  real(kind=8), private, pointer :: send_double_buffer_1d(:,:)     ! i, num_of_data
  real(kind=8), private, pointer :: recv_double_buffer_1d(:,:)     ! i*j, num_of_data

  interface set_data
    module procedure set_data_double_1d
  end interface

  interface get_data
    module procedure get_data_double_1d
  end interface

  character(len=STR_SHORT), private, dimension(MAX_GRID) :: my_grid_name
  character(len=STR_SHORT), private, dimension(MAX_MODEL) :: my_component_name
  integer, private :: my_grid_counter

#ifdef EXCHANGE_BY_MPI_RMA
  integer :: nmax_hist = 5
  integer, allocatable :: memwin_array(:)
  real(kind=8), allocatable, target :: sendbuff(:,:)
  integer, allocatable :: sendcount(:),recvcount(:)
#endif

contains

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine init_grid()
  use jcup_comp, only : get_num_of_total_component
  use jcup_grid_base, only : init_grid_base
  use jcup_pe_array, only : init_pe_array
  use jcup_exchange_grid, only : init_exchange_grid

  implicit none
  integer :: mdl1, mdl2, grd
  
  call init_grid_base()

  allocate(send_array(get_num_of_total_component(), get_num_of_total_component()))
  allocate(recv_array(get_num_of_total_component(), get_num_of_total_component()))

  do mdl1 = 1, get_num_of_total_component()
    do mdl2 = 1, get_num_of_total_component()
      allocate(send_array(mdl1,mdl2)%pe_array(NUM_OF_EXCHANGE_GRID))
      allocate(recv_array(mdl1,mdl2)%pe_array(NUM_OF_EXCHANGE_GRID))
      do grd = 1, NUM_OF_EXCHANGE_GRID
        call init_pe_array(send_array(mdl1,mdl2)%pe_array(grd))
        call init_pe_array(recv_array(mdl1,mdl2)%pe_array(grd))
      end do
    end do
  end do

  allocate(a_grid(get_num_of_total_component(), get_num_of_total_component()))
  do mdl1 = 1, get_num_of_total_component()
    do mdl2 = 1, get_num_of_total_component()
      allocate(a_grid(mdl1,mdl2)%ex_grid(NUM_OF_EXCHANGE_GRID))
      do grd = 1, NUM_OF_EXCHANGE_GRID
        call init_exchange_grid(a_grid(mdl1,mdl2)%ex_grid(grd))
      end do
    end do
  end do

  is_InitGrid=.true.

  my_grid_counter = 0

  send_double_buffer_1d => NULL()
  recv_double_buffer_1d => NULL()

end subroutine init_grid

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine def_grid(grid_index, component_name, grid_name)
  use jcup_grid_base, only : set_my_area_info
  implicit none
  integer, intent(IN) :: grid_index(:)
  character(len=*), intent(IN) :: component_name
  character(len=*), intent(IN) :: grid_name

  !!!call check_grid_index(grid_index, component_name, grid_name) ! 20140314 T.Arakawa comment out

  my_grid_counter = my_grid_counter+1
  my_component_name(my_grid_counter) = trim(component_name)
  my_grid_name(my_grid_counter) = trim(grid_name)

  call set_my_area_info(grid_index, component_name, grid_name)

end subroutine def_grid

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine check_grid_index(grid_index, component_name, grid_name)
  use jcup_utils, only : error
  implicit none
  integer, intent(IN) :: grid_index(:)
  character(len=*), intent(IN) :: component_name
  character(len=*), intent(IN) :: grid_name
  integer :: gindex
  integer :: i, j

  if (size(grid_index) > maxval(grid_index)-minval(grid_index)+1) then
    call error("def_grid", "grid_index check error, component: "//trim(component_name)//", grid: "//trim(grid_name))
  end if

  do i = 1, size(grid_index)
    gindex = grid_index(i)
    do j = i+1, size(grid_index)
      if (gindex == grid_index(j)) then
        call error("def_grid", "grid_index check error, component: "//trim(component_name)//", grid: "//trim(grid_name))
      end if
    end do
  end do

end subroutine check_grid_index

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine end_def()
  use jcup_grid_base, only : exchange_grid_info
  implicit none

  call set_grid()
  call exchange_grid_info()

end subroutine end_def

!=======+=========+=========+=========+=========+=========+=========+=========+

integer function GetNumOfMyGrid()
  implicit none

  GetNumOfMyGrid = my_grid_counter

end function GetNumOfMyGrid

!=======+=========+=========+=========+=========+=========+=========+=========+

integer function get_my_grid_num(grid_name)
  use jcup_constant, only : NO_GRID
  use jcup_grid_base, only : get_comp_name_from_grid_name, get_grid_num
  implicit none
  character(len=*), intent(IN) :: grid_name
  integer :: i
  character(len=STR_SHORT) :: component_name

  component_name = get_comp_name_from_grid_name(grid_name)

  get_my_grid_num = get_grid_num(component_name, grid_name)

end function get_my_grid_num

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine set_grid()
  use jcup_grid_base, only : get_num_of_component, get_num_of_grid, get_num_of_point
  implicit none
  integer :: cmp, grd, array_size_1d

  array_size_1d = 0
  do cmp = 1, get_num_of_component()
    do grd = 1, get_num_of_grid(cmp)
      array_size_1d = max(array_size_1d, get_num_of_point(cmp, grd))
    end do
  end do

  allocate(recv_double_buffer_1d(1:array_size_1d,1:NUM_OF_EXCHANGE_DATA))

end subroutine set_grid

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine destruct_grid()
  use jcup_grid_base, only : destruct_grid_base
  implicit none
  integer :: i

  call destruct_grid_base()

  deallocate(send_array, recv_array)

  if (associated(recv_double_buffer_1d)) deallocate(recv_double_buffer_1d)

  deallocate(a_grid)

end subroutine

!=======+=========+=========+=========+=========+=========+=========+=========+

logical function is_my_grid(grid_name)
  implicit none
  character(len=*), intent(IN) :: grid_name

  integer :: i

  is_my_grid = .true.

  do i = 1, my_grid_counter
    if (trim(grid_name) == trim(my_grid_name(i))) return
  end do

  is_my_grid = .false.

end function is_my_grid

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine set_current_e_grid(my_comp_id, send_comp_id, mapping_tag)
  implicit none
  integer, intent(IN) :: my_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag

  peg => a_grid(my_comp_id, send_comp_id)%ex_grid(mapping_tag)

end subroutine set_current_e_grid

!=======+=========+=========+=========+=========+=========+=========+=========+
! 2014/02/27 
subroutine get_operation_index(my_comp_name, send_comp_name, mapping_tag, num_of_operation, operation_index)
  use jcup_comp, only : get_comp_id_from_name
  implicit none
  character(len=*), intent(IN) :: my_comp_name, send_comp_name
  integer, intent(IN) :: mapping_tag
  integer, intent(INOUT) :: num_of_operation
  integer, pointer :: operation_index(:)
  integer :: my_comp_id, send_comp_id

  my_comp_id = get_comp_id_from_name(my_comp_name)
  send_comp_id = get_comp_id_from_name(send_comp_name)


  call set_current_e_grid(my_comp_id, send_comp_id, mapping_tag)

  num_of_operation = size(peg%local_operation_index)
  operation_index => peg%local_operation_index

end subroutine get_operation_index

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine get_send_grid_index(my_comp_name, send_comp_name, mapping_tag, num_of_send_grid_point, send_grid_index) 
  use jcup_comp, only : get_comp_id_from_name
  implicit none
  character(len=*), intent(IN) :: my_comp_name, send_comp_name
  integer, intent(IN) :: mapping_tag
  integer, intent(INOUT) :: num_of_send_grid_point
  integer, pointer :: send_grid_index(:)
  integer :: my_comp_id, send_comp_id

  my_comp_id = get_comp_id_from_name(my_comp_name)
  send_comp_id = get_comp_id_from_name(send_comp_name)


  call set_current_e_grid(my_comp_id, send_comp_id, mapping_tag)

  num_of_send_grid_point = peg%num_of_my_send_point
  send_grid_index => peg%global_index_of_my_send_point

end subroutine get_send_grid_index

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine get_recv_grid_index(my_comp_name, send_comp_name, mapping_tag, num_of_recv_grid_point, recv_grid_index) 
  use jcup_comp, only : get_comp_id_from_name
  implicit none
  character(len=*), intent(IN) :: my_comp_name, send_comp_name
  integer, intent(IN) :: mapping_tag
  integer, intent(INOUT) :: num_of_recv_grid_point
  integer, pointer :: recv_grid_index(:)
  integer :: my_comp_id, send_comp_id

  my_comp_id = get_comp_id_from_name(my_comp_name)
  send_comp_id = get_comp_id_from_name(send_comp_name)


  call set_current_e_grid(my_comp_id, send_comp_id, mapping_tag)

  num_of_recv_grid_point = peg%num_of_my_recv_point
  recv_grid_index => peg%global_index_of_my_recv_point

end subroutine get_recv_grid_index

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine get_interpolation_index(my_comp_name, send_comp_name, mapping_tag, num_of_operation, &
                                   operation_index, send_data_index, recv_data_index, &
                                                    send_coef_index, recv_coef_index)
  use jcup_comp, only : get_comp_id_from_name
  implicit none
  character(len=*), intent(IN) :: my_comp_name, send_comp_name
  integer, intent(IN) :: mapping_tag
  integer, intent(INOUT) :: num_of_operation
  integer, pointer :: operation_index(:) 
  integer, pointer :: send_data_index(:), recv_data_index(:)
  integer, pointer :: send_coef_index(:), recv_coef_index(:)
  integer :: my_comp_id, send_comp_id

  my_comp_id = get_comp_id_from_name(my_comp_name)
  send_comp_id = get_comp_id_from_name(send_comp_name)

  call set_current_e_grid(my_comp_id, send_comp_id, mapping_tag)

  num_of_operation = size(peg%local_operation_index)
  operation_index => peg%local_operation_index
  send_coef_index => peg%send_index_converter
  recv_coef_index => peg%recv_index_converter
  send_data_index => peg%remapped_send_index
  recv_data_index => peg%recv_index_converter

end subroutine get_interpolation_index


!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine set_grid_mapping_1d(send_comp_id, recv_comp_id, mapping_tag, &
                               send_grid_tag, recv_grid_tag, send_grid_index, recv_grid_index)
  use jcup_mpi_lib, only : jml_isLocalLeader, jml_BcastLocal, jml_GetMyrank, jml_GetMyrankGlobal, &
                           jml_ScatterLocal, jml_ScatterVLocal, jml_SendLocal, jml_RecvLocal
  use jcup_utils, only : error, put_log
  use jcup_grid_base, only : get_num_of_pe, get_pe_num
  implicit none
  integer, intent(IN) :: send_comp_id
  integer, intent(IN) :: recv_comp_id
  integer, intent(IN) :: mapping_tag 
  integer, intent(IN) :: send_grid_tag
  integer, intent(IN) :: recv_grid_tag
  integer, intent(IN) :: send_grid_index(:) ! send grid index of whole interpolation operation
  integer, intent(IN) :: recv_grid_index(:) ! recv grid index of whole interpolation operation

  integer, allocatable :: num_of_local_operation(:)
  integer, allocatable :: send_buffer(:), local_operation(:)
  integer, allocatable :: send_pe(:) 
  integer, allocatable :: offset(:)
  integer, allocatable :: global_pe_num(:) ! pe number of send component on global operation
  integer, allocatable :: local_pe_num(:) ! pe number of send component on my local operation
  integer :: num_of_my_operation
  integer :: mapping_num
  integer :: send_grid_num
  integer :: recv_grid_num
  integer :: num_of_pe
  integer :: int_buffer(3)
  integer :: pe, g, i, j, k
  integer :: p, d
  integer :: counter

  if (.not.is_InitGrid) then
    call error("set_grid_mapping_1d","InitGrid not called")
  end if

  !!!write(0,*) "set_grid_mapping_1d 1 ", send_comp_id, recv_comp_id

  if (jml_isLocalLeader(recv_comp_id)) then
    int_buffer(1) = mapping_tag
    int_buffer(2) = send_grid_tag
    int_buffer(3) = recv_grid_tag
  end if

  call put_log("set_mapping_table 1 ", 2)

  call jml_BcastLocal(recv_comp_id, int_buffer,1,3)
  mapping_num = int_buffer(1)
  send_grid_num = int_buffer(2)
  recv_grid_num = int_buffer(3)

  num_of_pe = get_num_of_pe(recv_comp_id)

  peg => a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_num)

  !!!write(0,*) "set_grid_mapping_1d 2 ", send_comp_id, recv_comp_id

  call put_log("set_mapping_table 2 ", 2)

  if (jml_isLocalLeader(recv_comp_id)) then

    allocate(num_of_local_operation(num_of_pe))
    allocate(offset(num_of_pe))
    allocate(send_buffer(size(recv_grid_index)))
    allocate(local_operation(size(recv_grid_index)))
    allocate(send_pe(size(recv_grid_index)))
    allocate(global_pe_num(size(recv_grid_index)))

    num_of_local_operation(:) = 0
    offset(:) = 0
    do i = 1, size(recv_grid_index)
        !!!!write(0,*) "cal pe ", i, recv_grid_index(i), send_grid_index(i)

        pe = get_pe_num(recv_comp_id, recv_grid_num, recv_grid_index(i))
        if (pe <= size(num_of_local_operation)) then
          num_of_local_operation(pe) = num_of_local_operation(pe)+1
        end if
        send_pe(i) = pe
        local_operation(i) = i
        global_pe_num(i) = get_pe_num(send_comp_id, send_grid_num, send_grid_index(i))
    end do

    do i = 2, num_of_pe
      offset(i) = offset(i-1)+num_of_local_operation(i-1)
    end do

    num_of_my_operation = num_of_local_operation(1)

    call jml_ScatterLocal(recv_comp_id, num_of_local_operation, 1, int_buffer)

  else
    allocate(num_of_local_operation(1))
    call jml_ScatterLocal(recv_comp_id, num_of_local_operation, 1, int_buffer)
    num_of_my_operation = int_buffer(1)
    deallocate(num_of_local_operation)
  end if

  call put_log("set_mapping_table 3 ", 2)

  !!!write(0,*) "set_grid_mapping_1d 3 ", send_comp_id, recv_comp_id

  allocate(peg%local_operation_index(num_of_my_operation))
  allocate(peg%local_send_grid_index(num_of_my_operation))
  allocate(peg%local_recv_grid_index(num_of_my_operation))
  allocate(peg%send_index_converter(num_of_my_operation))
  allocate(peg%recv_index_converter(num_of_my_operation))
  allocate(peg%remapped_send_index(num_of_my_operation))
  allocate(local_pe_num(num_of_my_operation))

  call put_log("set_mapping_table 4 ", 2)

  if (jml_isLocalLeader(recv_comp_id)) then

       call remap_send_array(local_operation, send_pe, offset, num_of_local_operation, send_buffer)
       call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                              peg%local_operation_index, num_of_my_operation)
       deallocate(local_operation)

       call remap_send_array(global_pe_num, send_pe, offset, num_of_local_operation, send_buffer)
       call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                              local_pe_num, num_of_my_operation)
       deallocate(global_pe_num)

       call remap_send_array(send_grid_index, send_pe, offset, num_of_local_operation, send_buffer)
       call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                              peg%local_send_grid_index, num_of_my_operation)

       call remap_send_array(recv_grid_index, send_pe, offset, num_of_local_operation, send_buffer)
       call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                              peg%local_recv_grid_index, num_of_my_operation)

       deallocate(send_buffer)
       deallocate(send_pe)
       deallocate(offset)
       deallocate(num_of_local_operation)
  else

      allocate(send_buffer(1))
      allocate(num_of_local_operation(1))
      allocate(offset(1))
      call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                             peg%local_operation_index, num_of_my_operation)
      call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                             local_pe_num, num_of_my_operation)
      call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                             peg%local_send_grid_index, num_of_my_operation)
      call jml_ScatterVLocal(recv_comp_id, send_buffer, num_of_local_operation, offset, &
                             peg%local_recv_grid_index, num_of_my_operation)
      deallocate(send_buffer)
      deallocate(num_of_local_operation)
      deallocate(offset)
  end if

  call put_log("set_mapping_table 5 ", 2)

  call set_local_grid_mapping_1d(recv_comp_id, send_comp_id, mapping_num, send_grid_num,  &
                                 recv_grid_num, peg%local_send_grid_index, peg%local_recv_grid_index, local_pe_num)

  deallocate(local_pe_num)

  call put_log("set_mapping_table 6 ", 2)

  allocate(peg%send_double_buffer_1d(recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_num)%num_of_point, &
                                     NUM_OF_EXCHANGE_DATA))


end subroutine set_grid_mapping_1d

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine remap_send_array(send_array, pe_array, offset, pe_counter, remapped_array)
  implicit none
  integer, intent(IN) :: send_array(:)
  integer, intent(IN) :: pe_array(:), offset(:)
  integer, intent(INOUT) :: pe_counter(:)
  integer, intent(INOUT) :: remapped_array(:)

  integer, allocatable :: remap_table(:)
  integer :: i, pe

  allocate(remap_table(size(send_array)))
  pe_counter(:) = 0
  remap_table(:) = 0 
  do i = 1, size(send_array)
    if ((pe_array(i)>0).and.(pe_array(i)<=size(pe_counter))) then
      pe_counter(pe_array(i)) = pe_counter(pe_array(i))+1
      remap_table(i) = offset(pe_array(i))+pe_counter(pe_array(i))
      if (remap_table(i)<=0) then
        write(0,*) "remap error !!!!!!!! ",i,pe_array(i), pe_counter(pe_array(i))
      end if
    else
    end if
  end do 
 
  do i = 1, size(send_array)
    remapped_array(remap_table(i)) = send_array(i)
  end do

  deallocate(remap_table)

end subroutine remap_send_array

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine cal_recv_index_converter(comp_id, grid_tag)
  use jcup_grid_base, only : global_index_to_local_index
  implicit none
  integer, intent(IN) :: comp_id, grid_tag
  integer :: i

  do i = 1, size(peg%local_recv_grid_index)
    call global_index_to_local_index(comp_id, grid_tag, peg%local_recv_grid_index(i), peg%recv_index_converter(i))
  end do

end subroutine cal_recv_index_converter

!=======+=========+=========+=========+=========+=========+=========+=========+
! 2017/01/09 [NEW]
subroutine cal_and_set_my_local_grid_index(local_index_array, num_of_point, local_grid_index)
  use jcup_utils, only : sort_int_1d
  implicit none
  integer, intent(IN)  :: local_index_array(:) ! index array of my operation
  integer, intent(OUT) :: num_of_point
  integer, pointer     :: local_grid_index(:)
  integer :: array_size
  integer :: max_data
  integer :: true_counter
  integer, allocatable :: sorted_array(:)
  integer :: i

  array_size = size(local_index_array)
  if (array_size==0) then
    allocate(local_grid_index(0))
    return
  end if

  allocate(sorted_array(array_size))

  sorted_array(:) = local_index_array(:)

  call sort_int_1d(array_size, sorted_array)

  max_data = sorted_array(1)
  num_of_point = 1

  do i = 1, array_size
    if (max_data < sorted_array(i)) then
      num_of_point = num_of_point + 1
      max_data = sorted_array(i)
    end if
  end do      

  allocate(local_grid_index(num_of_point))

  max_data = sorted_array(1)
  true_counter = 1
  local_grid_index(true_counter) = max_data

  do i = 1, array_size
    if (max_data < sorted_array(i)) then
      true_counter = true_counter + 1      
      max_data = sorted_array(i)
      local_grid_index(true_counter) = max_data
    end if
  end do

  deallocate(sorted_array)
  
end subroutine cal_and_set_my_local_grid_index

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine cal_num_of_my_grid_point_old(local_index_array, num_of_point)
  implicit none
  integer, intent(IN)  :: local_index_array(:) ! index array of my operation
  integer, intent(OUT) :: num_of_point
  integer :: array_size
  integer :: s_min, s_max
  integer :: true_counter
  logical, allocatable :: send_flag(:)
  integer :: i

  array_size = size(local_index_array)

  if (array_size==0) then
    num_of_point = 0
    return
  end if

  s_min = minval(local_index_array)
  s_max = maxval(local_index_array)

  !write(0,*) "cal_num_of_my_grid_point ", array_size, s_min, s_max

  allocate(send_flag(s_min:s_max))

  send_flag(:) = .false.

  do i = 1, array_size
    send_flag(local_index_array(i)) = .true.
  end do      

  true_counter = 0
  do i = s_min, s_max
    if (send_flag(i)) then
      true_counter = true_counter+1
    end if
  end do

  num_of_point = true_counter

  deallocate(send_flag)
  
end subroutine cal_num_of_my_grid_point_old

!=======+=========+=========+=========+=========+=========+=========+=========+
! 2017/01/09 [MOD] sorting method
subroutine cal_num_of_my_grid_point(local_index_array, num_of_point)
  use jcup_utils, only : sort_int_1d
  implicit none
  integer, intent(IN)  :: local_index_array(:) ! index array of my operation
  integer, intent(OUT) :: num_of_point
  integer :: array_size
  integer :: max_data
  integer :: true_counter
  integer, allocatable :: sorted_array(:)
  integer :: i

  array_size = size(local_index_array)

  if (array_size==0) then
    num_of_point = 0
    return
  end if

  allocate(sorted_array(array_size))

  sorted_array(:) = local_index_array(:)

  call sort_int_1d(array_size, sorted_array)

  max_data = sorted_array(1)
  num_of_point = 1

  do i = 1, array_size
    if (max_data < sorted_array(i)) then
      num_of_point = num_of_point + 1
      max_data = sorted_array(i)
    end if
  end do      

  deallocate(sorted_array)

end subroutine cal_num_of_my_grid_point

!=======+=========+=========+=========+=========+=========+=========+=========+
 
subroutine set_my_local_grid_index_old(local_index_array, local_grid_index)
  implicit none
  integer, intent(IN)  :: local_index_array(:) ! index array of my operation
  integer, intent(INOUT) :: local_grid_index(:)
  integer :: array_size
  integer :: s_min, s_max
  integer :: true_counter
  logical, allocatable :: send_flag(:)
  integer :: i

  array_size = size(local_index_array)
  if (array_size==0) then
    return
  end if

  s_min = minval(local_index_array)
  s_max = maxval(local_index_array)

  allocate(send_flag(s_min:s_max))

  send_flag(:) = .false.

  do i = 1, array_size
    send_flag(local_index_array(i)) = .true.
  end do      

  true_counter = 0
  do i = s_min, s_max
    if (send_flag(i)) then
      true_counter = true_counter+1
      local_grid_index(true_counter) = i
    end if
  end do

  deallocate(send_flag)
  
end subroutine set_my_local_grid_index_old

!=======+=========+=========+=========+=========+=========+=========+=========+
! 2017/01/09 [MOD] radix sort method
subroutine set_my_local_grid_index(local_index_array, local_grid_index)
  use jcup_utils, only : sort_int_1d
  implicit none
  integer, intent(IN)  :: local_index_array(:) ! index array of my operation
  integer, intent(INOUT) :: local_grid_index(:)
  integer :: array_size
  integer :: max_data
  integer :: true_counter
  integer, allocatable :: sorted_array(:)
  integer :: i

  array_size = size(local_index_array)
  if (array_size==0) then
    return
  end if

  allocate(sorted_array(array_size))

  sorted_array(:) = local_index_array(:)

  call sort_int_1d(array_size, sorted_array)

  max_data = sorted_array(1)
  true_counter = 1
  local_grid_index(true_counter) = max_data

  do i = 1, array_size
    if (max_data < sorted_array(i)) then
      true_counter = true_counter + 1      
      max_data = sorted_array(i)
      local_grid_index(true_counter) = max_data
    end if
  end do

  deallocate(sorted_array)
  
end subroutine set_my_local_grid_index

!=======+=========+=========+=========+=========+=========+=========+=========+
! 2016/12/27 [NEW]
subroutine set_grid_mapping_1d_local(send_comp_id, recv_comp_id, mapping_tag, &
                                     send_grid_tag, recv_grid_tag, num_of_index, &
                                     send_grid_index, recv_grid_index, local_pe_num)
  use jcup_mpi_lib, only : jml_isLocalLeader, jml_BcastLocal, jml_GetMyrank, jml_GetMyrankGlobal, &
                           jml_ScatterLocal, jml_ScatterVLocal, jml_SendLocal, jml_RecvLocal
  use jcup_utils, only : error, put_log
  use jcup_grid_base, only : get_num_of_pe
  implicit none
  integer, intent(IN) :: send_comp_id
  integer, intent(IN) :: recv_comp_id
  integer, intent(IN) :: mapping_tag 
  integer, intent(IN) :: send_grid_tag
  integer, intent(IN) :: recv_grid_tag
  integer, intent(IN) :: num_of_index       ! array size
  integer, intent(IN) :: send_grid_index(:) ! send grid index of local interpolation operation
  integer, intent(IN) :: recv_grid_index(:) ! recv grid index of local interpolation operation
  integer, intent(IN) :: local_pe_num(:)    ! pe numeber of send component on my local operation

  integer :: num_of_my_operation
  integer :: mapping_num
  integer :: send_grid_num
  integer :: recv_grid_num
  integer :: num_of_pe
  integer :: int_buffer(3)
  integer :: pe, g, i, j, k
  integer :: p, d
  integer :: counter

  if (.not.is_InitGrid) then
    call error("set_grid_mapping_1d_local","InitGrid not called")
  end if

  !!!write(0,*) "set_grid_mapping_1d 1 ", send_comp_id, recv_comp_id

  if (jml_isLocalLeader(recv_comp_id)) then
    int_buffer(1) = mapping_tag
    int_buffer(2) = send_grid_tag
    int_buffer(3) = recv_grid_tag
  end if

  call put_log("set_mapping_table_local 1 ", 2)

  call jml_BcastLocal(recv_comp_id, int_buffer,1,3)
  mapping_num = int_buffer(1)
  send_grid_num = int_buffer(2)
  recv_grid_num = int_buffer(3)

  num_of_pe = get_num_of_pe(recv_comp_id)

  peg => a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_num)

  !!!write(0,*) "set_grid_mapping_1d 2 ", send_comp_id, recv_comp_id

  call put_log("set_mapping_table_local 2 ", 2)

  num_of_my_operation = num_of_index !size(recv_grid_index)

  !write(0,*) "set_mapping_table_local 3 ", num_of_my_operation


  allocate(peg%local_operation_index(num_of_my_operation))
  allocate(peg%local_send_grid_index(num_of_my_operation))
  allocate(peg%local_recv_grid_index(num_of_my_operation))
  allocate(peg%send_index_converter(num_of_my_operation))
  allocate(peg%recv_index_converter(num_of_my_operation))
  allocate(peg%remapped_send_index(num_of_my_operation))

  call put_log("set_mapping_table_local 3 ", 2)

  peg%local_send_grid_index(:) = send_grid_index(:)
  peg%local_recv_grid_index(:) = recv_grid_index(:)

  call set_local_grid_mapping_1d(recv_comp_id, send_comp_id, mapping_num, send_grid_num,  &
                                 recv_grid_num, peg%local_send_grid_index, peg%local_recv_grid_index, local_pe_num)

  call put_log("set_mapping_table_local 4 ", 2)

  allocate(peg%send_double_buffer_1d(recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_num)%num_of_point, &
                                     NUM_OF_EXCHANGE_DATA))

end subroutine set_grid_mapping_1d_local

!=======+=========+=========+=========+=========+=========+=========+=========+
! 2017/01/09 [MOD] to call cal_and_set_my_local_grid_index
subroutine set_local_grid_mapping_1d(recv_comp_id, send_comp_id, mapping_tag, &
                                     send_grid_tag, recv_grid_tag, send_grid, recv_grid, send_pe_num)
  use jcup_pe_array, only : write_pe_array_info
  use jcup_grid_base, only : local_area_type, get_my_local_area_ptr
  use jcup_utils, only : put_log, sort_int_1d, binary_search
  use jcup_mpi_lib, only : jml_GetMyrankGlobal
  implicit none
  integer, intent(IN) :: recv_comp_id
  integer, intent(IN) :: send_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: send_grid_tag
  integer, intent(IN) :: recv_grid_tag
  integer, intent(IN) :: send_grid(:), recv_grid(:) ! send grid number and recv grid number on local operation
  integer, intent(IN) :: send_pe_num(:) ! send pe number on local operation 
  integer, allocatable :: pe_num_of_my_send_point(:)
  integer, allocatable :: sort_grid(:), sort_index(:)
  integer :: i, j
  type(local_area_type), pointer :: local_area_ptr

  ! debug write start
  !character(len=128) :: file_name
  !integer :: fid

  !write(file_name, "(A,I5.5,A)") "local_mapping_table.",jml_GetMyrankGlobal(),".txt"
  !fid = 654
  !open(unit = fid, &
  !     file = trim(file_name), &
  !     form = "formatted")

  !do i = 1, size(send_grid)
  !  write(fid, *) recv_grid(i), send_grid(i), send_pe_num(i)
  !end do

  !close(fid)
  ! debug write end

  !write(0,*) send_pe_num

  call put_log("set_local_grid_mapping_1d 1", 2)

  !call cal_num_of_my_grid_point(recv_grid, peg%num_of_my_recv_point)
  !allocate(peg%global_index_of_my_recv_point(peg%num_of_my_recv_point))
  !call set_my_local_grid_index(recv_grid, peg%global_index_of_my_recv_point)

  call cal_and_set_my_local_grid_index(recv_grid, peg%num_of_my_recv_point, &
                                                  peg%global_index_of_my_recv_point)

  peg%recv_index_converter(:) = 0

  call put_log("set_local_grid_mapping_1d 2", 2)

  recv_grid_do : do j = 1, size(recv_grid)

     peg%recv_index_converter(j) =  binary_search(peg%global_index_of_my_recv_point, recv_grid(j))

    !do i = j, size(peg%global_index_of_my_recv_point)
    ! if (recv_grid(j)==peg%global_index_of_my_recv_point(i)) then
    !   peg%recv_index_converter(j) = i
    !   cycle recv_grid_do
    ! end if
    !end do

    !do i = 1, j - 1
    !  if (recv_grid(j)==peg%global_index_of_my_recv_point(i)) then
    !    peg%recv_index_converter(j) = i
    !    cycle recv_grid_do
    !  end if
    !end do

  end do recv_grid_do

  call put_log("set_local_grid_mapping_1d 3", 2)

  !call cal_num_of_my_grid_point_old(send_grid, peg%num_of_my_send_point)
  !allocate(peg%global_index_of_my_send_point(peg%num_of_my_send_point))
  !call set_my_local_grid_index_old(send_grid, peg%global_index_of_my_send_point)

  call cal_and_set_my_local_grid_index(send_grid, peg%num_of_my_send_point, &
                                                  peg%global_index_of_my_send_point)

  allocate(pe_num_of_my_send_point(peg%num_of_my_send_point))

  call put_log("set_local_grid_mapping_1d 4", 2)

  !goto 8000
  ! new
  allocate(sort_grid(size(send_grid)))
  allocate(sort_index(size(send_grid)))
  do i = 1, size(send_grid)
    sort_grid(i) = send_grid(i)
    sort_index(i) = i
  end do

  call sort_int_1d(size(send_grid), sort_grid, sort_index)
  
  ! binary seeach

  do i = 1, peg%num_of_my_send_point
     j = binary_search(sort_grid, peg%global_index_of_my_send_point(i))
     if ((j<=0).or.(j>size(send_grid))) then
        write(0, *) "ERROR of binary search ", i, peg%global_index_of_my_send_point(i) 
        stop 9999
     end if
     if (j>0) then
        pe_num_of_my_send_point(i) = send_pe_num(sort_index(j))
     end if
  end do

  deallocate(sort_grid, sort_index)
 
    
  !8000 continue
  !do i = 1, peg%num_of_my_send_point
  !  do j = 1, size(send_grid)
  !    if (peg%global_index_of_my_send_point(i)==send_grid(j)) then
  !      pe_num_of_my_send_point(i) = send_pe_num(j)
  !      exit
  !    end if
  !  end do
  !end do

  !write(900+jml_GetMyrankGlobal(), *) pe_num_of_my_send_point
  
  call put_log("set_local_grid_mapping_1d 5", 2)

  peg%send_index_converter(:) = 0

  send_grid_do : do j = 1, size(send_grid)
    peg%send_index_converter(j) =  binary_search(peg%global_index_of_my_send_point, send_grid(j))
    !do i = j, size(peg%global_index_of_my_send_point)
    !  if (send_grid(j)==peg%global_index_of_my_send_point(i)) then
    !    peg%send_index_converter(j) = i
    !    cycle send_grid_do
    !  end if
    !end do
    !do i = 1, j-1
    !  if (send_grid(j)==peg%global_index_of_my_send_point(i)) then
    !    peg%send_index_converter(j) = i
    !    cycle send_grid_do
    !  end if
    !end do
  end do send_grid_do

  call put_log("set_local_grid_mapping_1d 6", 2)

  call make_pe_array(send_comp_id, send_grid_tag, peg%global_index_of_my_send_point, &
                     pe_num_of_my_send_point, &
                     recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)) 

   !write(0,*) "make_pe_array result ", jml_GetMyrankGlobal(), recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%num_of_pe

  call put_log("set_local_grid_mapping_1d 7", 2)

  do i = 1, size(peg%send_index_converter)
    j = peg%send_index_converter(i)
    peg%remapped_send_index(i) = recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%data_index(j)
  end do

  deallocate(pe_num_of_my_send_point)

  allocate(peg%local_index(size(peg%local_recv_grid_index)))

  peg%local_index(:) = 0
  local_area_ptr => get_my_local_area_ptr(recv_comp_id, recv_grid_tag)


  allocate(sort_grid(size(local_area_ptr%grid_index)))
  allocate(sort_index(size(sort_grid)))
  do i = 1, size(sort_grid)
    sort_grid(i) = local_area_ptr%grid_index(i)
    sort_index(i) = i
  end do

  call sort_int_1d(size(sort_grid), sort_grid, sort_index)
  
  ! binary seeach

  do i = 1, size(recv_grid)
     j = binary_search(sort_grid, recv_grid(i))
     if ((j<=0).or.(j>size(sort_index))) then
        write(0, *) "ERROR of binary search ", j, i, recv_grid(i)
        stop 9999
     end if
     if (j>0) then
        peg%local_index(i) = sort_index(j)
     end if
  end do

  deallocate(sort_grid, sort_index)


  !do i = 1, size(recv_grid)
  !  do j = 1, size(local_area_ptr%grid_index)
  !    if (recv_grid(i) == local_area_ptr%grid_index(j)) then
  !      peg%local_index(i) = j
  !      exit
  !    end if
  !  end do
  !end do

  call put_log("set_local_grid_mapping_1d 8", 2)

 end subroutine set_local_grid_mapping_1d
 
!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine make_pe_array(send_comp_id, send_grid_tag, local_send_index, send_pe_num, pe_array)
  use jcup_grid_base, only : get_num_of_pe
  implicit none
  integer, intent(IN) :: send_comp_id
  integer, intent(IN) :: send_grid_tag
  integer, intent(IN) :: local_send_index(:)
  integer, intent(IN) :: send_pe_num(:)
  type(pe_array_type) :: pe_array

  integer, allocatable :: send_grid_num(:)
  integer :: num_of_send_pe, num_of_send_data
  integer :: index
  integer :: pe_num
  integer :: i, j

  allocate(send_grid_num(get_num_of_pe(send_comp_id)))
  
  send_grid_num = 0
  do i = 1, size(local_send_index)
    pe_num = send_pe_num(i) !cal_pe_num(send_task_num, send_comp_num, send_grid_tag, local_send_index(i))
    send_grid_num(pe_num) = send_grid_num(pe_num) + 1
  end do  

  num_of_send_pe = 0
  pe_array%num_of_point = size(local_send_index)
  allocate(pe_array%data_point(pe_array%num_of_point))
  allocate(pe_array%data_index(pe_array%num_of_point))
  allocate(pe_array%data_buffer(pe_array%num_of_point*NUM_OF_EXCHANGE_DATA))

  do i = 1, size(send_grid_num)
    if (send_grid_num(i)>0) then 
      num_of_send_pe = num_of_send_pe + 1
    end if
  end do

  pe_array%num_of_pe = num_of_send_pe
  allocate(pe_array%pa(num_of_send_pe))
  
  num_of_send_pe = 0
  num_of_send_data = 1
  do i = 1, size(send_grid_num)
    if (send_grid_num(i)>0) then
      num_of_send_pe = num_of_send_pe + 1
      pe_array%pa(num_of_send_pe)%pe_num = i
      pe_array%pa(num_of_send_pe)%s_point = num_of_send_data 
      num_of_send_data = num_of_send_data+send_grid_num(i)
      pe_array%pa(num_of_send_pe)%e_point = num_of_send_data-1
      !write(0,*) num_of_send_pe, i, pe_array%pa(num_of_send_pe)%s_point, pe_array%pa(num_of_send_pe)%e_point
    end if
  end do

  send_grid_num = 0
  do i = 1, size(local_send_index)
    pe_num = send_pe_num(i) ! cal_pe_num(send_task_num, send_comp_num, send_grid_tag, local_send_index(i))
    send_grid_num(pe_num) = send_grid_num(pe_num) + 1
    do j = 1, pe_array%num_of_pe
      if (pe_array%pa(j)%pe_num == pe_num) then
        index = pe_array%pa(j)%s_point+send_grid_num(pe_num)-1
        pe_array%data_index(i) = index
        pe_array%data_point(index) = local_send_index(i)
      end if
    end do
  end do  

  deallocate(send_grid_num)

end subroutine make_pe_array

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine exchange_grid_mapping(send_comp_id, recv_comp_id, mapping_tag)
  use jcup_mpi_lib, only : jml_SendModel, jml_RecvModel
  use jcup_comp, only : is_my_component
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id, mapping_tag
  integer :: is, ie, pe
  integer :: i

  if (is_my_component(recv_comp_id)) call send_mapping_info(send_comp_id, recv_comp_id, mapping_tag)
  if (is_my_component(send_comp_id)) call recv_mapping_info(send_comp_id, recv_comp_id, mapping_tag)

  if (is_my_component(recv_comp_id)) then
    do i = 1, recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%num_of_pe
      is = recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%pa(i)%s_point
      ie = recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%pa(i)%e_point
      pe = recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%pa(i)%pe_num
      call jml_SendModel(recv_comp_id,recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%data_point, is, ie, &
                         send_comp_id, pe-1)
    end do
  end if

  if (is_my_component(send_comp_id)) then
    do i = 1, send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%num_of_pe
      is = send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%pa(i)%s_point
      ie = send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%pa(i)%e_point
      pe = send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%pa(i)%pe_num
      call jml_RecvModel(send_comp_id, send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%data_point, is, ie, &
                         recv_comp_id, pe-1)
    end do
  end if

end subroutine exchange_grid_mapping


!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine send_grid_mapping(send_comp_id, recv_comp_id, mapping_tag)
  use jcup_utils, only : put_log
  use jcup_mpi_lib, only : jml_SendModel
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer :: is, ie, pe
  integer :: i

  call put_log("send_mapping_info start")
  call send_mapping_info(send_comp_id, recv_comp_id, mapping_tag)
  call put_log("send_mapping_info ok")

  call put_log("data point send start")
  do i = 1, recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%num_of_pe
    is = recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%pa(i)%s_point
    ie = recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%pa(i)%e_point
    pe = recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%pa(i)%pe_num
    call jml_SendModel(recv_comp_id,recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)%data_point, is, ie, &
                       send_comp_id, pe-1)
  end do
  call put_log("data point send ok")

end subroutine send_grid_mapping

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine send_mapping_info(send_comp_id, recv_comp_id, mapping_tag)
  use jcup_mpi_lib, only : jml_isLocalLeader, jml_SendLocal, jml_RecvLocal, jml_SendLeader
  use jcup_grid_base, only : get_num_of_pe
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag

  integer, allocatable :: info_matrix(:,:)
  integer, allocatable :: int_buffer(:)
  integer :: send_pe, my_pe
  integer :: i, j

  send_pe = get_num_of_pe(send_comp_id)
  my_pe   = get_num_of_pe(recv_comp_id)

  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

  allocate(int_buffer(send_pe))
  if (jml_isLocalLeader(recv_comp_id)) then
    allocate(info_matrix(my_pe, send_pe))
    info_matrix = 0
    do i = 1, rpa%num_of_pe
      info_matrix(1, rpa%pa(i)%pe_num) = rpa%pa(i)%e_point-rpa%pa(i)%s_point+1
    end do
    do i = 2, my_pe
      int_buffer = 0
      call jml_RecvLocal(recv_comp_id,int_buffer,1,send_pe,i-1)
      do j = 1, send_pe
        info_matrix(i,j) = int_buffer(j)
      end do     
    end do
    call jml_SendLeader(info_matrix,1,my_pe,1,send_pe, send_comp_id-1)
  else
    allocate(info_matrix(1,1))
    int_buffer = 0
    do i = 1, rpa%num_of_pe
      int_buffer(rpa%pa(i)%pe_num) = rpa%pa(i)%e_point-rpa%pa(i)%s_point+1
    end do
    call jml_SendLocal(recv_comp_id,int_buffer, 1, send_pe, 0)
  end if

  deallocate(int_buffer)
  deallocate(info_matrix)

end subroutine send_mapping_info

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine recv_grid_mapping(send_comp_id, recv_comp_id, mapping_tag)
  use jcup_utils, only : put_log
  use jcup_mpi_lib, only : jml_RecvModel
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer :: is, ie, pe
  integer :: i

  call put_log("recv_mapping_info start")
  call recv_mapping_info(send_comp_id, recv_comp_id, mapping_tag)
  call put_log("recv_mapping_info ok")

  call put_log("data point recv start")
  do i = 1, send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%num_of_pe
    is = send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%pa(i)%s_point
    ie = send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%pa(i)%e_point
    pe = send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%pa(i)%pe_num
    call jml_RecvModel(send_comp_id, send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)%data_point, is, ie, &
                       recv_comp_id, pe-1)
  end do
  call put_log("data point recv ok")

end subroutine recv_grid_mapping

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine recv_mapping_info(send_comp_id, recv_comp_id, mapping_tag)
  use jcup_constant, only  : STR_LONG
  use jcup_utils, only     : put_log
  use jcup_mpi_lib, only   : jml_isLocalLeader, jml_SendLocal, jml_RecvLocal, jml_RecvLeader, jml_GetMyrank
  use jcup_grid_base, only : get_num_of_pe
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag

  integer, allocatable :: info_matrix(:,:)
  integer, allocatable :: int_buffer(:)
  integer :: recv_pe, my_pe
  integer :: i, j
  character(len=STR_LONG) :: log_str

  recv_pe = get_num_of_pe(recv_comp_id)
  my_pe   = get_num_of_pe(send_comp_id)

  allocate(int_buffer(recv_pe))

  if (jml_isLocalLeader(send_comp_id)) then
    allocate(info_matrix(recv_pe, my_pe))
    call jml_RecvLeader(info_matrix, 1, recv_pe, 1, my_pe, recv_comp_id-1)

    do i = 2, my_pe
      do j = 1, recv_pe
        int_buffer(j) = info_matrix(j,i)
      end do
      call jml_SendLocal(send_comp_id, int_buffer, 1, recv_pe, i-1)
    end do
    do i = 1, recv_pe
      int_buffer(i) = info_matrix(i,1)
    end do
  else
    allocate(info_matrix(1,1))
    call jml_RecvLocal(send_comp_id, int_buffer, 1, recv_pe, 0)
  end if

  call put_log("init_send_array start")
  call init_send_array(int_buffer, send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag))
  call put_log("init_send_array ok")

  deallocate(int_buffer)
  deallocate(info_matrix)

end subroutine recv_mapping_info

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine init_send_array(array_info, send_array)
  use jcup_constant, only : STR_LONG
  use jcup_utils, only : put_log, error
  implicit none
  integer, intent(IN) :: array_info(:)
  type(pe_array_type), intent(INOUT) :: send_array
  integer :: counter
  integer :: s_point, e_point
  integer :: i
  character(len=STR_LONG) :: log_str

  counter = 0
  do i = 1, size(array_info)
    if (array_info(i)>0) counter = counter+1
  end do  
  
  send_array%num_of_pe = counter
  allocate(send_array%pa(counter))

  counter = 0
  s_point = 1
  e_point = 0
  do i = 1, size(array_info)
    if (array_info(i)>0) then
      e_point = s_point + array_info(i)-1
      counter = counter+1
      send_array%pa(counter)%pe_num = i
      send_array%pa(counter)%s_point = s_point
      send_array%pa(counter)%e_point = e_point
      s_point = e_point+1
    end if
  end do  

  write(log_str, '("init_send_array, data_buffer allocation start. array size = ",I10,I10)') e_point, NUM_OF_EXCHANGE_DATA
  call put_log(trim(log_str))
  send_array%num_of_point = e_point  
  allocate(send_array%data_point(e_point))
  if (.not.associated(send_array%data_point)) then
    call error("init_send_array", "array send_array%data_point allocation error")
  end if

  allocate(send_array%data_buffer(e_point*NUM_OF_EXCHANGE_DATA))
  if (.not.associated(send_array%data_buffer)) then
    call error("init_send_array", "array send_array%data_buffer allocation error")
  end if

  call put_log("init_send_array, data_buffer allocation ok")

end subroutine init_send_array

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine finish_grid_mapping(send_comp_id, recv_comp_id, mapping_tag, send_grid_tag, recv_grid_tag)
  use jcup_utils, only : put_log, sort_int_1d, binary_search
  use jcup_mpi_lib, only :  jml_set_num_of_isend, jml_set_num_of_irecv
  use jcup_comp, only : is_my_component
  use jcup_grid_base, only : local_area_type, get_my_local_area_ptr, global_index_to_local_index
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: send_grid_tag
  integer, intent(IN) :: recv_grid_tag
  type(local_area_type), pointer :: local_area_ptr
  integer, allocatable :: sort_grid(:), sort_index(:)
  integer :: counter
  integer :: p, d, index 
  integer :: i

  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

#ifndef ADVANCED_EXCHANGE
  if (is_my_component(send_comp_id)) then
    call jml_set_num_of_isend(spa%num_of_pe*10000+100)
  end if
  if (is_my_component(recv_comp_id)) then
    call jml_set_num_of_irecv(rpa%num_of_pe*10000+100)
  end if
#else
  if (is_my_component(send_comp_id)) then
    call jml_set_num_of_isend(10000)
  end if
  if (is_my_component(recv_comp_id)) then
    call jml_set_num_of_irecv(10000)
  end if
#endif

  if (is_my_component(send_comp_id)) then
    call put_log("global_index_to_local_index start")

    counter = 0
    do p = 1, spa%num_of_pe
      do d = spa%pa(p)%s_point, spa%pa(p)%e_point
        counter = counter + 1
      end do
    end do

    peg => a_grid(send_comp_id, recv_comp_id)%ex_grid(mapping_tag)
    allocate(peg%local_send_index(counter))

    local_area_ptr => get_my_local_area_ptr(send_comp_id, send_grid_tag)

    allocate(sort_grid(size(local_area_ptr%grid_index)))
    allocate(sort_index(size(local_area_ptr%grid_index)))
    do i = 1, size(sort_grid)
      sort_grid(i) = local_area_ptr%grid_index(i)
      sort_index(i) = i
    end do

    call sort_int_1d(size(sort_grid), sort_grid, sort_index)
  
    counter = 0    

    do p = 1, spa%num_of_pe
      do d = spa%pa(p)%s_point, spa%pa(p)%e_point
        counter = counter+1

        peg%local_send_index(counter) = sort_index(binary_search(sort_grid, spa%data_point(d)))

      end do
    end do 

    deallocate(sort_grid)
    deallocate(sort_index)

    call put_log("global_index_to_local_index ok")

  end if


end subroutine finish_grid_mapping

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine finish_grid_mapping_org(send_comp_id, recv_comp_id, mapping_tag, send_grid_tag, recv_grid_tag)
  use jcup_utils, only : put_log
  use jcup_mpi_lib, only :  jml_set_num_of_isend, jml_set_num_of_irecv
  use jcup_comp, only : is_my_component
  use jcup_grid_base, only : global_index_to_local_index
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: send_grid_tag
  integer, intent(IN) :: recv_grid_tag
  integer :: counter
  integer :: p, d, index 

  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

#ifndef ADVANCED_EXCHANGE
  if (is_my_component(send_comp_id)) then
    call jml_set_num_of_isend(spa%num_of_pe*10000+100)
  end if
  if (is_my_component(recv_comp_id)) then
    call jml_set_num_of_irecv(rpa%num_of_pe*10000+100)
  end if
#else
  if (is_my_component(send_comp_id)) then
    call jml_set_num_of_isend(10000)
  end if
  if (is_my_component(recv_comp_id)) then
    call jml_set_num_of_irecv(10000)
  end if
#endif

  if (is_my_component(send_comp_id)) then
    call put_log("global_index_to_local_index start")

    counter = 0
    do p = 1, spa%num_of_pe
      do d = spa%pa(p)%s_point, spa%pa(p)%e_point
        counter = counter + 1
      end do
    end do

    peg => a_grid(send_comp_id, recv_comp_id)%ex_grid(mapping_tag)
    allocate(peg%local_send_index(counter))

    counter = 0    

    do p = 1, spa%num_of_pe
      do d = spa%pa(p)%s_point, spa%pa(p)%e_point
        counter = counter+1
        call global_index_to_local_index(send_comp_id, send_grid_tag, spa%data_point(d), index)
        peg%local_send_index(counter) = index ! spa%data_point(d)
      end do
    end do 

    call put_log("global_index_to_local_index ok")

  end if


end subroutine finish_grid_mapping_org

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine write_grid_mapping_info()
  use jcup_mpi_lib, only : jml_GetMyrankGlobal
  use jcup_utils, only : open_log_file, close_log_file, DETAIL_LOG, get_log_level
  use jcup_comp, only : get_num_of_total_component
  use jcup_pe_array, only : write_pe_array_info
  implicit none
  integer :: i, j, k
  character(len=4) :: pe_num
  integer, parameter :: GRID_LOG_UNIT = 222
  integer :: log_unit

  if (get_log_level() /= DETAIL_LOG) return

  pe_num = '0000'
  write(pe_num,'(I4.4)') jml_GetMyrankGlobal()

  log_unit = GRID_LOG_UNIT+jml_GetMyrankGlobal()

  call open_log_file("./grid.mapping.log.PE"//pe_num, log_unit)

  do i = 1, get_num_of_total_component()
    do j = 1, get_num_of_total_component()
      if (size(send_array(i,j)%pe_array) > 0) then
        write(log_unit, '("SEND PE ARRAY, send_comp_id=",I2,", recv_comp_id=",I2)') i, j
        do k = 1, size(send_array(i,j)%pe_array) 
           if (send_array(i,j)%pe_array(k)%num_of_pe>0) then
             call write_pe_array_info(log_unit, send_array(i,j)%pe_array(k))
           end if
        end do
      end if
      if (size(recv_array(i,j)%pe_array) > 0) then
        write(log_unit, '("RECV PE ARRAY, recv_comp_id=",I2,", send_comp_id=",I2)') i, j
        do k = 1, size(recv_array(i,j)%pe_array) 
           if (recv_array(i,j)%pe_array(k)%num_of_pe>0) then
             call write_pe_array_info(log_unit, recv_array(i,j)%pe_array(k))
           end if
        end do
      end if
    end do
  end do


  call close_log_file(log_unit)

end subroutine write_grid_mapping_info

!=======+=========+=========+=========+=========+=========+=========+=========+

logical function is_overlap(is1, ie1, js1, je1, is2, ie2, js2, je2)
  implicit none
  integer, intent(IN) :: is1, ie1, js1, je1
  integer, intent(IN) :: is2, ie2, js2, je2

  is_overlap = .false.

  if (is1 > ie2) return
  if (ie1 < is2) return
  if (js1 > je2) return
  if (je1 < js2) return
  is_overlap = .true.

end function is_overlap

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine set_data_double_1d(data)
  implicit none
  real(kind=8), pointer :: data(:,:)

  send_double_buffer_1d => data

end subroutine set_data_double_1d 

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine get_data_double_1d(my_comp_id, send_comp_id, mapping_tag, data, num_of_data)
  use jcup_mpi_lib, only : jml_GetMyrankGlobal
  implicit none
  integer, intent(IN) :: my_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag
  real(kind=8), intent(INOUT) :: data(:,:)
  integer, intent(IN) :: num_of_data
  integer :: d, k, i, j

    call set_current_e_grid(my_comp_id, send_comp_id, mapping_tag)

    do d = 1, num_of_data
      do k  = 1, size(peg%local_recv_grid_index)
        data(peg%local_index(k),d) = recv_double_buffer_1d(peg%recv_index_converter(k),d)
        !!!!!write(610+jml_GetMyrankGlobal(), *) k, peg%recv_index_converter(k), recv_double_buffer_1d(peg%recv_index_converter(k),d)
      end do
    end do

    !!!!!do k = 1, size(data,1)
    !!!!!   write(710+jml_GetMyrankGlobal(), *) k, data(k,1)
    !!!!!end do

end subroutine get_data_double_1d

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine convert_send_1d_data_to_1d(send_comp_id, recv_comp_id, mapping_tag, data, data_num)
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  real(kind=8), intent(IN) :: data(:)
  integer, intent(IN) :: data_num
  integer :: offset
  integer :: i, j, d, p
  integer :: counter


  peg => a_grid(send_comp_id, recv_comp_id)%ex_grid(mapping_tag)
  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  counter = 0
  do p = 1, spa%num_of_pe
    offset = (spa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
    offset = offset+(spa%pa(p)%e_point-spa%pa(p)%s_point+1)*(data_num-1)
    do d = spa%pa(p)%s_point, spa%pa(p)%e_point
      counter=counter+1
      spa%data_buffer(offset+d-spa%pa(p)%s_point+1) = data(peg%local_send_index(counter))
    end do
  end do
  
end subroutine convert_send_1d_data_to_1d

!=======+=========+=========+=========+=========+=========+=========+=========+
!> 2018/07/23 for nowait send
function get_send_data_buffer_size(send_comp_id, recv_comp_id) result(res)
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer :: res, buffer_size
  integer :: i
  
  res = 0

  do i = 1, size(send_array(send_comp_id, recv_comp_id)%pe_array)
     
    buffer_size = size(send_array(send_comp_id, recv_comp_id)%pe_array(i)%data_buffer)
    if (res < buffer_size) res = buffer_size
  end do
 
end function get_send_data_buffer_size

!=======+=========+=========+=========+=========+=========+=========+=========+
!> 2018/07/23 for nowait send

subroutine convert_send_1d_data_to_1d_nowait(send_comp_id, recv_comp_id, mapping_tag, data, data_num, send_buffer)
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  real(kind=8), intent(IN) :: data(:)
  integer, intent(IN) :: data_num
  real(kind=8), intent(INOUT) :: send_buffer(:)
  integer :: offset
  integer :: i, j, d, p
  integer :: counter

  peg => a_grid(send_comp_id, recv_comp_id)%ex_grid(mapping_tag)
  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  counter = 0
  do p = 1, spa%num_of_pe
    offset = (spa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
    offset = offset+(spa%pa(p)%e_point-spa%pa(p)%s_point+1)*(data_num-1)
    do d = spa%pa(p)%s_point, spa%pa(p)%e_point
      counter=counter+1
      send_buffer(offset+d-spa%pa(p)%s_point+1) = data(peg%local_send_index(counter))
    end do
  end do
  
end subroutine convert_send_1d_data_to_1d_nowait
                                     

!=======+=========+=========+=========+=========+=========+=========+=========+
! this subroutine is called from jcup_exchange.f90 immediate data send mode
!
subroutine send_data_1d(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id)
  use jcup_mpi_lib, only : jml_ISendModel, jml_send_waitall
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntToStr, put_log
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id

  integer :: offset
  integer :: recv_pe
  integer :: is, ie
  integer :: d, i
  real(kind=8), pointer :: data_ptr

  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  call put_log("send_data_start")

    do d = 1, num_of_data
      call convert_send_1d_data_to_1d(send_comp_id, recv_comp_id, mapping_tag, send_double_buffer_1d(:,d),d)
    end do

    do i = 1, spa%num_of_pe
      offset = (spa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      recv_pe = spa%pa(i)%pe_num
      is = spa%pa(i)%s_point
      ie = spa%pa(i)%e_point
      select case(data_type)
        case(REAL_DATA)
        case(DOUBLE_DATA)
        call put_log("ISend "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
        data_ptr => spa%data_buffer(offset+1)
        call jml_ISendModel(send_comp_id, data_ptr, offset+1, offset+(ie-is+1)*num_of_data, &
                            recv_comp_id, recv_pe-1, exchange_data_id)
        call put_log("ISend finish "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
      end select 
    end do

    call jml_send_waitall()

end subroutine send_data_1d

!=======+=========+=========+=========+=========+=========+=========+=========+
! this subroutine is called from jcup_exchange.f90 immediate data recv mode
!
subroutine recv_data_1d(recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id)
  use jcup_mpi_lib, only : jml_IRecvModel, jml_recv_waitall
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntTOStr, put_log
  implicit none
  integer, intent(IN) :: recv_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id

  integer :: offset
  integer :: send_pe
  integer :: is, ie
  integer :: d, i, j, p
  real(kind=8), pointer :: data_ptr

  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

  call put_log("recv_data_start")
    do i = 1, rpa%num_of_pe
      offset = (rpa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      send_pe = rpa%pa(i)%pe_num
      is = rpa%pa(i)%s_point
      ie = rpa%pa(i)%e_point
      select case(data_type)
      case(REAL_DATA)

      case(DOUBLE_DATA)
         call put_log("IRecv "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data))// &
                      " exchange tag "//trim(IntToStr(exchange_data_id)))
        data_ptr => rpa%data_buffer(offset+1)
        call jml_IRecvModel(recv_comp_id, data_ptr, offset+1, offset+(ie-is+1)*num_of_data, &
                            send_comp_id, send_pe-1, exchange_data_id)
        call put_log("IRecv finish "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
      end select
    end do

  call jml_recv_waitall()

  call put_log("recv_data, data receive completed")
  
  do p = 1, rpa%num_of_pe
    do d = 1, num_of_data
      offset = (rpa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
      offset = offset+(rpa%pa(p)%e_point-rpa%pa(p)%s_point+1)*(d-1)
      do i = rpa%pa(p)%s_point, rpa%pa(p)%e_point
        a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)%send_double_buffer_1d(i,d) = &
                       rpa%data_buffer(offset+i-rpa%pa(p)%s_point+1)
      end do
    end do
  end do
  
end subroutine recv_data_1d

#ifdef EXCHANGE_BY_MPI_RMA

!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+                RMA EXCHANGE MODE SUBROUTINES              +=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine set_nmax_history(nhist)
  use jcup_utils, only : put_log, IntToStr
  integer, intent(IN) :: nhist
  nmax_hist = nhist
  call put_log("set size of history : "//trim(IntToStr(nhist)))
end subroutine set_nmax_history

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine send_data_1d_nowait(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id, &
        send_buffer)
  use jcup_mpi_lib, only : jml_WinCreateModel, jml_WinFenceModel, jml_WinUnLock_all, jml_WinLock_all, jml_BcastLocal
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntToStr, put_log
  use jcup_comp, only : is_my_component, get_num_of_total_component
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id
  real(kind=8), target, intent(INOUT) :: send_buffer(:)
  integer :: offset
  integer :: recv_pe
  integer :: is, ie
  integer :: d, i, n
  integer :: spoint, epoint
  integer :: memwin
  real(kind=8), pointer :: data_ptr, data_ptr2


  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  call put_log("send_data_start")
  do d = 1, num_of_data
     call convert_send_1d_data_to_1d_nowait(send_comp_id, recv_comp_id, mapping_tag, &
                                            send_double_buffer_1d(:,d),d, send_buffer)
  end do
  
  if(.not.allocated(sendbuff)) then
    allocate(sendbuff(size(send_buffer), nmax_hist))
    spa%send_buffer_size = size(send_buffer)
  endif

  call set_spoint_send(send_comp_id, recv_comp_id, mapping_tag, exchange_data_id)

  if(.not.allocated(sendcount)) then
    n = get_num_of_total_component()
    allocate(sendcount(n))
    sendcount=0
  endif

  if(.not.allocated(memwin_array)) then
    n = get_num_of_total_component()
    allocate(memwin_array(n))
    memwin_array = 0
  endif
  sendcount(recv_comp_id) = sendcount(recv_comp_id) + 1

  call get_se(spa, spoint, epoint)
  sendbuff(1:size(send_buffer),mod(sendcount(recv_comp_id)-1,nmax_hist)+1) = send_buffer(1:size(send_buffer))
  data_ptr => sendbuff(1,1)

  call jml_WinCreateModel(send_comp_id, data_ptr, 1, &
       size(send_buffer), recv_comp_id, memwin_array(recv_comp_id))

end subroutine send_data_1d_nowait

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine recv_data(recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id)
  use jcup_mpi_lib, only : jml_WinCreateModel, jml_WinFenceModel, jml_GetModel, jml_recv_waitall, jml_WinLock, jml_WinUnLock &
          , jml_WinLock_all, jml_WinUnLock_all, jml_BcastLocal, jml_GetMyrankGlobal
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntTOStr, put_log
  use jcup_comp, only : is_my_component, get_num_of_total_component
  implicit none
  integer, intent(IN) :: recv_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id

  integer :: offset, offset_send, offset_base, offset_recv
  integer :: send_pe
  integer :: is, ie
  integer :: d, i, j, p, n
  real(kind=8), pointer :: data_ptr
  integer :: spoint, epoint, memwin

  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

  call set_spoint_recv(send_comp_id, recv_comp_id, mapping_tag, exchange_data_id)

  call put_log("recv_data_start")
  if(.not.allocated(recvcount)) then
    n = get_num_of_total_component()
    allocate(recvcount(n))
    recvcount=0
  endif
  recvcount(send_comp_id) = recvcount(send_comp_id)+1

  memwin = memwin_array(send_comp_id)
  offset_base = mod(recvcount(send_comp_id)-1,nmax_hist)*rpa%send_buffer_size
  call jml_WinLock_all(memwin)
  do i = 1, rpa%num_of_pe
    offset_recv = (rpa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
    offset =  (rpa%pa(i)%s_point_send-1)*NUM_OF_EXCHANGE_DATA
    offset_send = offset_base + offset
    send_pe = rpa%pa(i)%pe_num
    is = rpa%pa(i)%s_point
    ie = rpa%pa(i)%e_point
    select case(data_type)
    case(REAL_DATA)

    case(DOUBLE_DATA)
      call put_log("Get "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data))// &
                   " exchange tag "//trim(IntToStr(exchange_data_id)))
      data_ptr => rpa%data_buffer(offset_recv+1)
      call jml_GetModel(recv_comp_id, data_ptr, offset_recv+1, &
           offset_recv+(ie-is+1)*num_of_data, offset_send, &
           send_comp_id, send_pe-1,memwin)
      call put_log("Get finish "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
    end select
  end do
  call jml_WinUnLock_all(memwin)
  call put_log("recv_data, data receive completed")
  
  do p = 1, rpa%num_of_pe
    do d = 1, num_of_data
      offset = (rpa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
      offset = offset+(rpa%pa(p)%e_point-rpa%pa(p)%s_point+1)*(d-1)
      do i = rpa%pa(p)%s_point, rpa%pa(p)%e_point
        a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)%send_double_buffer_1d(i,d) = &
                       rpa%data_buffer(offset+i-rpa%pa(p)%s_point+1)
      end do
    end do
  end do
end subroutine recv_data

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine get_se(pa,spoint,epoint)
  type(pe_array_type), pointer, intent(IN) :: pa
  integer, intent(OUT) :: spoint, epoint
  integer :: i
  spoint = HUGE(0)
  epoint = 0
  do i=1,pa%num_of_pe
    if(pa%pa(i)%s_point<spoint) then
      spoint = pa%pa(i)%s_point 
    endif
    if(pa%pa(i)%e_point>epoint) then
      epoint = pa%pa(i)%e_point
    endif
  enddo
  return
end subroutine get_se

#else

!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+            SEND/RECV EXCHANGE MODE SUBROUTINES            +=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine send_data_1d_nowait(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id, send_buffer)
  use jcup_mpi_lib, only : jml_ISendModel, jml_send_waitall
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntToStr, put_log
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id
  real(kind=8), target, intent(INOUT) :: send_buffer(:)
  integer :: offset
  integer :: recv_pe
  integer :: is, ie
  integer :: d, i
  real(kind=8), pointer :: data_ptr

  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  call put_log("send_data_start")

  do d = 1, num_of_data
   call convert_send_1d_data_to_1d_nowait(send_comp_id, recv_comp_id, mapping_tag, &
                                              send_double_buffer_1d(:,d),d, send_buffer)
  end do

  do i = 1, spa%num_of_pe
    offset = (spa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
    recv_pe = spa%pa(i)%pe_num
    is = spa%pa(i)%s_point
    ie = spa%pa(i)%e_point
    select case(data_type)
    case(REAL_DATA)
    case(DOUBLE_DATA)
      call put_log("ISend NOWAIT "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data))// &
                   " exchange tag "//trim(IntToStr(exchange_data_id)))
      data_ptr => send_buffer(offset+1)
      call jml_ISendModel(send_comp_id, data_ptr, offset+1, offset+(ie-is+1)*num_of_data, &
                          recv_comp_id, recv_pe-1, exchange_data_id)
      call put_log("ISend NOWAIT finish "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
    end select 
  end do

end subroutine send_data_1d_nowait

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine recv_data(recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id)
  use jcup_mpi_lib, only : jml_IRecvModel, jml_recv_waitall
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntTOStr, put_log
  implicit none
  integer, intent(IN) :: recv_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id

  integer :: offset
  integer :: send_pe
  integer :: is, ie
  integer :: d, i, j, p
  real(kind=8), pointer :: data_ptr

  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

  call put_log("recv_data_start")
    do i = 1, rpa%num_of_pe
      offset = (rpa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      send_pe = rpa%pa(i)%pe_num
      is = rpa%pa(i)%s_point
      ie = rpa%pa(i)%e_point
      select case(data_type)
      case(REAL_DATA)

      case(DOUBLE_DATA)
         call put_log("IRecv "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data))// &
                      " exchange tag "//trim(IntToStr(exchange_data_id)))
        data_ptr => rpa%data_buffer(offset+1)
        call jml_IRecvModel(recv_comp_id, data_ptr, offset+1, offset+(ie-is+1)*num_of_data, &
                            send_comp_id, send_pe-1, exchange_data_id)
        call put_log("IRecv finish "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
      end select
    end do

  call jml_recv_waitall()
  call put_log("recv_data, data receive completed")
  
  do p = 1, rpa%num_of_pe
    do d = 1, num_of_data
      offset = (rpa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
      offset = offset+(rpa%pa(p)%e_point-rpa%pa(p)%s_point+1)*(d-1)
      do i = rpa%pa(p)%s_point, rpa%pa(p)%e_point
        a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)%send_double_buffer_1d(i,d) = &
                       rpa%data_buffer(offset+i-rpa%pa(p)%s_point+1)
      end do
    end do
  end do
  
end subroutine recv_data

#endif

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine recv_data_nowait(recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id)
  use jcup_mpi_lib, only : jml_IRecvModel, jml_recv_waitall
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntTOStr, put_log
  implicit none
  integer, intent(IN) :: recv_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id

  integer :: offset
  integer :: send_pe
  integer :: is, ie
  integer :: d, i, j, p
  real(kind=8), pointer :: data_ptr

  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

  call put_log("recv_data_start")
  !do d = 1, num_of_data
    do i = 1, rpa%num_of_pe
      offset = (rpa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      send_pe = rpa%pa(i)%pe_num
      is = rpa%pa(i)%s_point
      ie = rpa%pa(i)%e_point
      select case(data_type)
      case(REAL_DATA)
        !!!!!call jml_RecvModel(recv_array%data_buffer, is, ie, send_model, send_pe-1) 
      case(DOUBLE_DATA)
        call put_log("IRecv "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
        data_ptr => rpa%data_buffer(offset+1)
        call jml_IRecvModel(recv_comp_id, data_ptr, offset+1, offset+(ie-is+1)*num_of_data, &
                            send_comp_id, send_pe-1, exchange_data_id)
        call put_log("IRecv finish "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
      end select
    end do


  call put_log("recv_data, data receive completed")
  
  !send_double_buffer_1d = 0.d0

    !call put_log("recv_data_end")
  
end subroutine recv_data_nowait

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine send_recv_waitall(recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id)
  use jcup_mpi_lib, only : jml_send_waitall, jml_recv_waitall
  implicit none
  integer, intent(IN) :: recv_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id
  integer :: offset
  integer :: p, d, i

  write(0, *) "send_recv_waitall "
  call jml_send_waitall()
  write(0, *) "send_recv_waitall 1"
  call jml_recv_waitall()
  write(0, *) "send_recv_waitall 2"

  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

  do p = 1, rpa%num_of_pe
    do d = 1, num_of_data
      offset = (rpa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
      offset = offset+(rpa%pa(p)%e_point-rpa%pa(p)%s_point+1)*(d-1)
      do i = rpa%pa(p)%s_point, rpa%pa(p)%e_point
        a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)%send_double_buffer_1d(i,d) = &
                       rpa%data_buffer(offset+i-rpa%pa(p)%s_point+1)
      end do
    end do
  end do
  

end subroutine send_recv_waitall

#ifdef EXCHANGE_BY_MPI_RMA

!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+                RMA EXCHANGE MODE SUBROUTINES              +=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine init_mpi_rma()
  use jcup_mpi_lib, only : jml_Alloc_MemWindow
  use jcup_comp, only : get_num_of_total_component
  integer :: n

  n = get_num_of_total_component()
  call jml_Alloc_MemWindow(n)

end subroutine init_mpi_rma

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine finalize_mpi_rma()
  use jcup_mpi_lib, only : jml_WinFreeModel, jml_Dealloc_MemWindow
  use jcup_comp, only : get_num_of_total_component
  integer :: i, j

  do i = 1, get_num_of_total_component()
    do j = 1, get_num_of_total_component()
      call jml_WinFreeModel(i, j)
    enddo
  enddo

  call jml_Dealloc_MemWindow()

  if(allocated(memwin_array)) deallocate(memwin_array)
  if(allocated(sendcount)) deallocate(sendcount)
  if(allocated(recvcount)) deallocate(recvcount)

end subroutine finalize_mpi_rma

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine set_spoint_send(send_comp_id, recv_comp_id, mapping_tag,exchange_data_id)
  use jcup_mpi_lib, only : jml_ISendModel, jml_IRecvModel, jml_send_waitall, jml_recv_waitall
  use jcup_comp, only : is_my_component
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag, exchange_data_id
  integer, pointer :: iptr1, iptr2
  integer :: i

  spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)

  do i=1,spa%num_of_pe
    iptr1 => spa%send_buffer_size
    call jml_ISendModel(send_comp_id,iptr1,1,1,recv_comp_id,spa%pa(i)%pe_num-1,exchange_data_id)
    iptr2 => spa%pa(i)%s_point
    call jml_ISendModel(send_comp_id,iptr2,1,1,recv_comp_id,spa%pa(i)%pe_num-1,exchange_data_id)
  enddo

end subroutine set_spoint_send

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine set_spoint_recv(send_comp_id, recv_comp_id, mapping_tag,exchange_data_id)
  use jcup_mpi_lib, only : jml_ISendModel, jml_IRecvModel, jml_send_waitall, jml_recv_waitall
  use jcup_comp, only : is_my_component
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag, exchange_data_id
  integer, pointer :: iptr1, iptr2
  integer :: i

  rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)

  do i=1,rpa%num_of_pe
    iptr1 => rpa%send_buffer_size
    call jml_IRecvModel(recv_comp_id,iptr1,1,1,send_comp_id,rpa%pa(i)%pe_num-1,exchange_data_id)
    iptr2 => rpa%pa(i)%s_point_send
    call jml_IRecvModel(recv_comp_id,iptr2,1,1,send_comp_id,rpa%pa(i)%pe_num-1,exchange_data_id)
  enddo

  call jml_recv_waitall()

end subroutine set_spoint_recv

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine exchange_data_comp(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id, &
                              data_2d3d)
  use jcup_mpi_lib, only : &
    & jml_GetModelRankOffset, jml_WinCreateModel, jml_WinFenceModel, &
    & jml_GetModel, jml_GetMyrank, jml_GetMyrankModel, jml_ISendModel, jml_IRecvModel, &
    & jml_send_waitall, jml_recv_waitall
  use jcup_constant, only : DATA_2D, DATA_3D, REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntToStr, put_log, error
  use jcup_comp, only : is_my_component
  use mpi
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id
  integer, intent(IN) :: data_2d3d
  integer :: model_rank_offset
  integer :: offset, offset_recv, offset_send
  integer :: send_pe, recv_pe
  integer :: is, ie
  integer :: d, i, j, p
  integer :: spoint, epoint, myrank
  integer :: memwin
  real(kind=8), pointer :: data_ptr1, data_ptr2, data_ptr3
  integer, target :: num_of_pe
  integer, allocatable :: intar(:)
  integer, pointer :: iptr1, iptr2
  integer, allocatable, target :: ss_point(:)

  if (is_my_component(send_comp_id)) then
    spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  endif

  if (is_my_component(recv_comp_id)) then
    rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)
  endif

  if(is_my_component(send_comp_id)) then
    do i=1,spa%num_of_pe
      iptr1 => spa%pa(i)%s_point
      call jml_ISendModel(send_comp_id,iptr1,1,1,recv_comp_id,spa%pa(i)%pe_num-1)
    enddo
  endif

  if(is_my_component(recv_comp_id)) then
    allocate(ss_point(rpa%num_of_pe));ss_point=-1
    do i=1,rpa%num_of_pe
      !iptr2 => ss_point(i)
      iptr2 => rpa%pa(i)%s_point_send
      call jml_IRecvModel(recv_comp_id,iptr2,1,1,send_comp_id,rpa%pa(i)%pe_num-1)
    enddo
  endif

  if(is_my_component(send_comp_id)) call jml_send_waitall()
  if(is_my_component(recv_comp_id)) call jml_recv_waitall()
  
  if (is_my_component(send_comp_id)) then
    do d = 1, num_of_data
      call convert_send_1d_data_to_1d(send_comp_id, recv_comp_id, mapping_tag, send_double_buffer_1d(:,d),d)
    end do
  endif

  if (is_my_component(recv_comp_id)) then
    call get_se(rpa, spoint, epoint)
    offset = (spoint-1)*NUM_OF_EXCHANGE_DATA
    data_ptr2 => rpa%data_buffer(offset+1)
    call jml_WinCreateModel(recv_comp_id, data_ptr2, offset+1, &
         offset+(epoint-spoint+1)*num_of_data, send_comp_id, memwin)
    call jml_WinFenceModel(memwin)
  endif

  if (is_my_component(send_comp_id)) then
    call get_se(spa, spoint, epoint)
    offset = (spoint-1)*NUM_OF_EXCHANGE_DATA
    data_ptr1 => spa%data_buffer(offset+1)
    call jml_WinCreateModel(send_comp_id, data_ptr1, offset+1, &
         offset+(epoint-spoint+1)*num_of_data, recv_comp_id, memwin)
    call jml_WinFenceModel(memwin)
  endif

  if (is_my_component(recv_comp_id)) then
    rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)
    model_rank_offset = jml_GetModelRankOffset(recv_comp_id, send_comp_id)

    do i = 1, rpa%num_of_pe
      offset_recv = (rpa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      send_pe = rpa%pa(i)%pe_num! + model_rank_offset

      is = rpa%pa(i)%s_point
      ie = rpa%pa(i)%e_point
      if (send_pe-1+model_rank_offset==jml_GetMyrankModel(recv_comp_id, send_comp_id)) then ! same pe send recv

        spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)

        do p = 1, spa%num_of_pe
          if (spa%pa(p)%pe_num-1==jml_GetMyrank(recv_comp_id)) then
            offset_send = (spa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
            exit
          end if
        end do

        select case(data_type)
        case (REAL_DATA)
        case (DOUBLE_DATA)
          call put_log("Local Data Copy"//trim(IntToStr(send_pe))//" size "// &
                       trim(IntToStr((ie-is+1)*num_of_data)))
          do j = 1, (ie-is+1)*num_of_data
            rpa%data_buffer(offset_recv+j) = spa%data_buffer(offset_send+j)
          end do
          call put_log("Local Data Copy finish "//trim(IntToStr(send_pe))//" size "// &
                       trim(IntToStr((ie-is+1)*num_of_data)))
        end select
      else
        offset_recv = (rpa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
        send_pe = rpa%pa(i)%pe_num! + model_rank_offset
        is = rpa%pa(i)%s_point
        ie = rpa%pa(i)%e_point
        select case(data_type)
          case(REAL_DATA)
          case(DOUBLE_DATA)
          call put_log("Get "//trim(IntToStr(send_pe))//" size "// &
               trim(IntToStr((ie-is+1)*num_of_data)))
          data_ptr3 => rpa%data_buffer(offset_recv+1)
!          offset_send = (ss_point(i)-1)*NUM_OF_EXCHANGE_DATA
          offset_send = (rpa%pa(i)%s_point_send-1)*NUM_OF_EXCHANGE_DATA
          call jml_GetModel(recv_comp_id, data_ptr3, offset_recv+1, &
               offset_recv+(ie-is+1)*num_of_data, offset_send, &
               send_comp_id, send_pe-1,memwin)
          call put_log("Get finish "//trim(IntToStr(send_pe))//" size "// &
               trim(IntToStr((ie-is+1)*num_of_data)))
        end select
      endif
    enddo
  endif

  if(is_my_component(send_comp_id)) then
     call jml_WinFenceModel(memwin)
  endif

  if(is_my_component(recv_comp_id)) then
     call jml_WinFenceModel(memwin)
  end if

  if (is_my_component(recv_comp_id)) then
    do p = 1, rpa%num_of_pe
      do d = 1, num_of_data
        offset_recv = (rpa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
        offset_recv = offset_recv+(rpa%pa(p)%e_point-rpa%pa(p)%s_point+1)*(d-1)
        do i = rpa%pa(p)%s_point, rpa%pa(p)%e_point
          !!!!write(0,*) "exchange data ", rpa%data_buffer(offset_recv+i-rpa%pa(p)%s_point+1)
          a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)%send_double_buffer_1d(i,d) = &
                         rpa%data_buffer(offset_recv+i-rpa%pa(p)%s_point+1)
        end do
      end do
    end do
  end if
  if(is_my_component(recv_comp_id)) then
    deallocate(ss_point)
  endif

  contains

  subroutine get_se(pa,spoint,epoint)
    type(pe_array_type), pointer, intent(IN) :: pa
    integer, intent(OUT) :: spoint, epoint
    integer :: i
    spoint = HUGE(0)
    epoint = 0
    do i=1,pa%num_of_pe
      if(pa%pa(i)%s_point<spoint) then
        spoint = pa%pa(i)%s_point 
      endif
      if(pa%pa(i)%e_point>epoint) then
        epoint = pa%pa(i)%e_point
      endif
    enddo
    return
  end subroutine get_se

end subroutine exchange_data_comp

!=======+=========+=========+=========+=========+=========+=========+=========+

!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+            SEND/RECV EXCHANGE MODE SUBROUTINES            +=========+
!=======+=========+=========+=========+=========+=========+=========+=========+
!=======+=========+=========+=========+=========+=========+=========+=========+

#else
#ifndef ADVANCED_EXCHANGE

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine exchange_data_comp(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id, &
                              data_2d3d)
#else
!subroutine exchange_data_comp_org(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id, &
!                              data_2d3d)
#endif

  use jcup_mpi_lib, only : &
    & jml_GetModelRankOffset, jml_ISendModel, jml_IRecvModel, jml_send_waitall, jml_recv_waitall, &
    & jml_GetMyrank, jml_GetMyrankGlobal, jml_GetMyrankModel
  use jcup_constant, only : DATA_2D, DATA_3D, REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntToStr, put_log, error
  use jcup_comp, only : is_my_component
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id
  integer, intent(IN) :: data_2d3d
  integer :: model_rank_offset
  integer :: offset, offset_recv, offset_send
  integer :: send_pe, recv_pe
  integer :: is, ie
  integer :: d, i, j, p
  real(kind=8), pointer :: data_ptr1, data_ptr2, data_ptr3

  !!!!write(0,*) "exchange_data_comp 1 ", jml_GetMyrankGlobal(), send_comp_id, recv_comp_id, is_my_component(send_comp_id)

  if (is_my_component(send_comp_id)) then
    spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
    do d = 1, num_of_data
      call convert_send_1d_data_to_1d(send_comp_id, recv_comp_id, mapping_tag, send_double_buffer_1d(:,d),d)
    end do
  end if


  if (is_my_component(send_comp_id)) then
    model_rank_offset = jml_GetModelRankOffset(send_comp_id, recv_comp_id)

  !!!!write(0,*) "exchange_data_comp 2 ", jml_GetMyrankGlobal(), spa%num_of_pe

    do i = 1, spa%num_of_pe
      offset = (spa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      recv_pe = spa%pa(i)%pe_num! + model_rank_offset
      is = spa%pa(i)%s_point
      ie = spa%pa(i)%e_point
      if (recv_pe-1+model_rank_offset<jml_GetMyrankModel(send_comp_id, recv_comp_id)) then
        select case(data_type)
          case(REAL_DATA)
          case(DOUBLE_DATA)
          call put_log("ISend "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
          data_ptr1 => spa%data_buffer(offset+1)
          !!!!write(0,*) "jml_ISendModel 1 ", send_comp_id, recv_comp_id, recv_pe, spa%data_buffer(offset+1)
          call jml_ISendModel(send_comp_id, data_ptr1, offset+1, offset+(ie-is+1)*num_of_data, &
                              recv_comp_id, recv_pe-1, exchange_data_id)
            call put_log("ISend finish "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
        end select 
      end if
    end do
  end if

  !!!!write(0,*) "exchange_data_comp 2.9 ", jml_GetMyrankGlobal(), send_comp_id, recv_comp_id, mapping_tag

  if (is_my_component(recv_comp_id)) then
    rpa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)
    model_rank_offset = jml_GetModelRankOffset(recv_comp_id, send_comp_id)

  !!!!write(0,*) "exchange_data_comp 3 ", jml_GetMyrankGlobal(), model_rank_offset, rpa%num_of_pe

    do i = 1, rpa%num_of_pe
      offset_recv = (rpa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      send_pe = rpa%pa(i)%pe_num! + model_rank_offset

  !!!!write(0,*) "exchange_data_comp 3.1 ", jml_GetMyrankGlobal(), model_rank_offset, rpa%num_of_pe, size(spa%pa)

      is = rpa%pa(i)%s_point
      ie = rpa%pa(i)%e_point

      if (send_pe-1+model_rank_offset==jml_GetMyrankModel(recv_comp_id, send_comp_id)) then ! same pe send recv

        spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)

      !if (i > size(spa%pa)) then
      !  write(0,*) "exchange data_comp, data size error ", i, size(spa%pa), jml_GetMyrankModel(recv_comp_id, send_comp_id), &
      !   jml_GetMyrankGlobal(), send_comp_id, recv_comp_id, send_pe, model_rank_offset

      !  call error("exchange_data_comp", "data size error")
      !end if
        !!write(0,*) "cal offset_send ", spa%num_of_pe, jml_GetMyrankGlobal()
        do p = 1, spa%num_of_pe
          !!write(0,*) "cal offset_send ", p, spa%pa(p)%pe_num, jml_GetMyrank(recv_comp_id)
          if (spa%pa(p)%pe_num-1==jml_GetMyrank(recv_comp_id)) then
            offset_send = (spa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
            exit
          end if
        end do

        select case(data_type)
        case (REAL_DATA)
        case (DOUBLE_DATA)
          call put_log("Local Data Copy"//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
          do j = 1, (ie-is+1)*num_of_data
            rpa%data_buffer(offset_recv+j) = spa%data_buffer(offset_send+j)
          end do
          call put_log("Local Data Copy finish "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
        end select

      else

        select case(data_type)
        case(REAL_DATA)
        case(DOUBLE_DATA)
          call put_log("IRecv "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
          data_ptr2 => rpa%data_buffer(offset_recv+1)
          !!!!!write(0,*) "jml_IRecvModel ", send_comp_id, recv_comp_id, send_pe, rpa%data_buffer(offset_recv+1)
          call jml_IRecvModel(recv_comp_id, data_ptr2, offset_recv+1, offset_recv+(ie-is+1)*num_of_data, &
                              send_comp_id, send_pe-1, exchange_data_id)
          call put_log("IRecv finish "//trim(IntToStr(send_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
        end select
      end if

    end do
  end if


  if (is_my_component(send_comp_id)) then
    model_rank_offset = jml_GetModelRankOffset(send_comp_id, recv_comp_id)
    !!!!write(0,*) "exchange_data_comp 4 ", jml_GetMyrankGlobal(), model_rank_offset, spa%num_of_pe

    do i = 1, spa%num_of_pe
      offset = (spa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
      recv_pe = spa%pa(i)%pe_num! + model_rank_offset
      is = spa%pa(i)%s_point
      ie = spa%pa(i)%e_point
      if (recv_pe-1+model_rank_offset>jml_GetMyrankModel(send_comp_id, recv_comp_id)) then
        select case(data_type)
          case(REAL_DATA)
          case(DOUBLE_DATA)
            call put_log("ISend "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
            data_ptr3 => spa%data_buffer(offset+1)
            !!!!write(0,*) "jml_ISendModel 2 ", send_comp_id, recv_comp_id, recv_pe, spa%data_buffer(offset+1)
            call jml_ISendModel(send_comp_id, data_ptr3, offset+1, offset+(ie-is+1)*num_of_data, &
                                recv_comp_id, recv_pe-1, exchange_data_id)
            call put_log("ISend finish "//trim(IntToStr(recv_pe))//" size "//trim(IntToStr((ie-is+1)*num_of_data)))
        end select 
      end if
    end do
  end if

  call jml_send_waitall()
  call jml_recv_waitall()

  !send_double_buffer_1d = 0.d0

  !!!!write(0,*) "exchange_data_comp 5 ", jml_GetMyrankGlobal()

  if (is_my_component(recv_comp_id)) then
    do p = 1, rpa%num_of_pe
      do d = 1, num_of_data
        offset_recv = (rpa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
        offset_recv = offset_recv+(rpa%pa(p)%e_point-rpa%pa(p)%s_point+1)*(d-1)
        do i = rpa%pa(p)%s_point, rpa%pa(p)%e_point
          !!!!write(0,*) "exchange data ", rpa%data_buffer(offset_recv+i-rpa%pa(p)%s_point+1)
          a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)%send_double_buffer_1d(i,d) = &
                         rpa%data_buffer(offset_recv+i-rpa%pa(p)%s_point+1)
        end do
      end do
    end do
  end if

  !!!!write(0,*) "exchange_data_comp 6 ", jml_GetMyrankGlobal()

#ifndef ADVANCED_EXCHANGE
end subroutine exchange_data_comp
#else
!end subroutine exchange_data_comp_org
#endif
#endif

!=======+=========+=========+=========+=========+=========+=========+=========+
#ifdef ADVANCED_EXCHANGE
!subroutine exchange_data_comp(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id, &
!                              data_2d3d)
#else
subroutine exchange_data_comp_new(send_comp_id, recv_comp_id, mapping_tag, data_type, num_of_data, exchange_data_id, &
                                  data_2d3d)
#endif

  use jcup_mpi_lib, only : &
    & jml_GetModelRankOffset, jml_ISendModel, jml_IRecvModel, jml_send_waitall, jml_recv_waitall, &
    & jml_GetMyrank, jml_GetMyrankGlobal, jml_GetMyrankModel
  use jcup_constant, only : DATA_2D, DATA_3D, REAL_DATA, DOUBLE_DATA
  use jcup_utils, only : IntToStr, put_log, error
  use jcup_comp, only : is_my_component
  use jcup_intercomm, only : init_intercomm, init_my_info, set_my_info, set_boss_info, &
                             send_data_intercomm, recv_data_intercomm
  implicit none
  integer, intent(IN) :: send_comp_id, recv_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_data_id
  integer, intent(IN) :: data_2d3d
  integer :: model_rank_offset
  integer :: offset, offset_recv, offset_send
  integer :: send_pe, recv_pe
  integer :: is, ie
  integer :: d, i, j, p
  real(kind=8), pointer :: data_ptr1, data_ptr2, data_ptr3

  if (is_my_component(send_comp_id)) then
    spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
    do d = 1, num_of_data
      call convert_send_1d_data_to_1d(send_comp_id, recv_comp_id, mapping_tag, send_double_buffer_1d(:,d), d)
    end do
  end if

  call init_intercomm()
  if (is_my_component(send_comp_id)) then
    spa => send_array(send_comp_id, recv_comp_id)%pe_array(mapping_tag)
  else
    spa => recv_array(recv_comp_id, send_comp_id)%pe_array(mapping_tag)
  end if

  call init_my_info(send_comp_id, recv_comp_id, mapping_tag, spa%num_of_pe)
  do i = 1, spa%num_of_pe
    offset = (spa%pa(i)%s_point-1)*NUM_OF_EXCHANGE_DATA
    is = spa%pa(i)%s_point
    ie = spa%pa(i)%e_point
    call set_my_info(i, spa%pa(i)%pe_num-1, offset, ie-is+1) ! pe_num starts form 1 
  end do

  call set_boss_info()

  if (is_my_component(send_comp_id)) then
     call send_data_intercomm(spa%data_buffer, num_of_data, exchange_data_id)
  end if
  if (is_my_component(recv_comp_id)) then
     call recv_data_intercomm(spa%data_buffer, num_of_data, exchange_data_id)
  end if

  !call mpi_finalize(i)
  !stop 333

  if (is_my_component(recv_comp_id)) then
    do p = 1, spa%num_of_pe
      do d = 1, num_of_data
        offset_recv = (spa%pa(p)%s_point-1)*NUM_OF_EXCHANGE_DATA
        offset_recv = offset_recv+(spa%pa(p)%e_point-spa%pa(p)%s_point+1)*(d-1)
        do i = spa%pa(p)%s_point, spa%pa(p)%e_point
          a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)%send_double_buffer_1d(i,d) = &
                         spa%data_buffer(offset_recv+i-spa%pa(p)%s_point+1)
        end do
      end do
    end do
  end if

  !!!!write(0,*) "exchange_data_comp 6 ", jml_GetMyrankGlobal()

#ifdef ADVANCED_EXCHANGE
!end subroutine exchange_data_comp
#else
end subroutine exchange_data_comp_new
#endif

!=======+=========+=========+=========+=========+=========+=========+=========+

subroutine interpolate_data_1d(recv_comp_id, send_comp_id, mapping_tag, data_type, num_of_data, exchange_tag)
  use jcup_constant, only : REAL_DATA, DOUBLE_DATA
  !!!use jcup_interpolation, only : interpolate_data
  use jcup_config, only : get_comp_name_from_comp_id
  implicit none
  integer, intent(IN) :: recv_comp_id, send_comp_id
  integer, intent(IN) :: mapping_tag
  integer, intent(IN) :: data_type
  integer, intent(IN) :: num_of_data
  integer, intent(IN) :: exchange_tag(:)
  integer :: d, i, j, k

  peg => a_grid(recv_comp_id, send_comp_id)%ex_grid(mapping_tag)

  select case(data_type)
  case(REAL_DATA)
  case(DOUBLE_DATA)
    call interpolate_data(get_comp_name_from_comp_id(recv_comp_id), &
                          get_comp_name_from_comp_id(send_comp_id), &
                          mapping_tag, &
                    size(peg%send_double_buffer_1d,1), size(peg%send_double_buffer_1d,2), peg%send_double_buffer_1d, & 
                    size(recv_double_buffer_1d,1), size(recv_double_buffer_1d,2), recv_double_buffer_1d, &
                    num_of_data, size(exchange_tag), exchange_tag)

  end select

end subroutine interpolate_data_1d

end module jcup_grid
