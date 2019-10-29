subroutine multimode_decoder(ss,id1,params,nfsample)

  !$ use omp_lib
  use prog_args
  use timer_module, only: timer
  use ft8_decode
  use js8b_decode
  use js8c_decode
  use js8d_decode

  include 'jt9com.f90'
  include 'timer_common.inc'

  type, extends(ft8_decoder) :: counting_ft8_decoder
     integer :: decoded
  end type counting_ft8_decoder

  type, extends(js8b_decoder) :: counting_js8b_decoder
     integer :: decoded
  end type counting_js8b_decoder

  type, extends(js8c_decoder) :: counting_js8c_decoder
     integer :: decoded
  end type counting_js8c_decoder

  type, extends(js8d_decoder) :: counting_js8d_decoder
     integer :: decoded
  end type counting_js8d_decoder

  real ss(184,NSMAX)
  logical baddata,newdat65,newdat9,single_decode,bVHF,bad0,newdat
  integer*2 id1(NTMAX*12000)
  type(params_block) :: params
  character(len=20) :: datetime
  character(len=12) :: mycall, hiscall
  character(len=6) :: mygrid, hisgrid
  save
  type(counting_ft8_decoder)  :: my_js8a
  type(counting_js8b_decoder) :: my_js8b
  type(counting_js8c_decoder) :: my_js8c
  type(counting_js8d_decoder) :: my_js8d

  !cast C character arrays to Fortran character strings
  datetime=transfer(params%datetime, datetime)
  mycall=transfer(params%mycall,mycall)
  hiscall=transfer(params%hiscall,hiscall)
  mygrid=transfer(params%mygrid,mygrid)
  hisgrid=transfer(params%hisgrid,hisgrid)

  ! initialize decode counts
  my_js8a%decoded = 0
  my_js8b%decoded = 0
  my_js8c%decoded = 0
  my_js8d%decoded = 0

  single_decode=iand(params%nexp_decode,32).ne.0
  bVHF=iand(params%nexp_decode,64).ne.0
  if(mod(params%nranera,2).eq.0) ntrials=10**(params%nranera/2)
  if(mod(params%nranera,2).eq.1) ntrials=3*10**(params%nranera/2)
  if(params%nranera.eq.0) ntrials=0
  
10  nfail=0
  if(params%nmode.eq.8) then
    c2fox='            '
    g2fox='    '
    nsnrfox=-99
    nfreqfox=-99
    n30z=0
    nwrap=0
    nfox=0
  endif

  if(ios.ne.0) then
     nfail=nfail+1
     if(nfail.le.3) then
        call sleep_msec(10)
        go to 10
     endif
  endif

  if(params%nmode.eq.8 .and. params%nsubmode.eq.4) then
! We're in JS8 mode D
     call timer('decjs8d ',0)
     newdat=params%newdat
     call my_js8d%decode(js8d_decoded,id1,params%nQSOProgress,params%nfqso,    &
          params%nftx,newdat,params%nutc,params%nfa,params%nfb,              &
          params%nexp_decode,params%ndepth,logical(params%nagain),           &
          logical(params%lft8apon),logical(params%lapcqonly),params%napwid,  &
          mycall,mygrid,hiscall,hisgrid)
     call timer('decjs8d ',1)
     go to 800
  endif

  if(params%nmode.eq.8 .and. params%nsubmode.eq.2) then
! We're in JS8 mode C
     call timer('decjs8c ',0)
     newdat=params%newdat
     call my_js8c%decode(js8c_decoded,id1,params%nQSOProgress,params%nfqso,    &
          params%nftx,newdat,params%nutc,params%nfa,params%nfb,              &
          params%nexp_decode,params%ndepth,logical(params%nagain),           &
          logical(params%lft8apon),logical(params%lapcqonly),params%napwid,  &
          mycall,mygrid,hiscall,hisgrid)
     call timer('decjs8c ',1)
     go to 800
  endif

  if(params%nmode.eq.8 .and. params%nsubmode.eq.1) then
! We're in JS8 mode B
     call timer('decjs8b ',0)
     newdat=params%newdat
     call my_js8b%decode(js8b_decoded,id1,params%nQSOProgress,params%nfqso,    &
          params%nftx,newdat,params%nutc,params%nfa,params%nfb,              &
          params%nexp_decode,params%ndepth,logical(params%nagain),           &
          logical(params%lft8apon),logical(params%lapcqonly),params%napwid,  &
          mycall,mygrid,hiscall,hisgrid)
     call timer('decjs8b ',1)
     go to 800
  endif

  if(params%nmode.eq.8 .and. params%nsubmode.eq.0) then
! We're in JS8 mode A
     call timer('decjs8a ',0)
     newdat=params%newdat
     call my_js8a%decode(js8a_decoded,id1,params%nQSOProgress,params%nfqso,    &
          params%nftx,newdat,params%nutc,params%nfa,params%nfb,              &
          params%nexp_decode,params%ndepth,logical(params%nagain),           &
          logical(params%lft8apon),logical(params%lapcqonly),params%napwid,  &
          mycall,mygrid,hiscall,hisgrid)
     call timer('decjs8a ',1)
     go to 800
  endif

  rms=sqrt(dot_product(float(id1(300000:310000)),            &
       float(id1(300000:310000)))/10000.0)
  if(rms.lt.2.0) go to 800

! Zap data at start that might come from T/R switching transient?
  nadd=100
  k=0
  bad0=.false.
  do i=1,240
     sq=0.
     do n=1,nadd
        k=k+1
        sq=sq + float(id1(k))**2
     enddo
     rms=sqrt(sq/nadd)
     if(rms.gt.10000.0) then
        bad0=.true.
        kbad=k
        rmsbad=rms
     endif
  enddo
  if(bad0) then
     nz=min(NTMAX*12000,kbad+100)
!     id1(1:nz)=0                ! temporarily disabled as it can breaak the JT9 decoder, maybe others
  endif
  
  npts65=52*12000
  if(baddata(id1,npts65)) then
     nsynced=0
     ndecoded=0
     go to 800
  endif
 
  ntol65=params%ntol              !### is this OK? ###
  newdat65=params%newdat
  newdat9=params%newdat

!$call omp_set_dynamic(.true.)

800 ndecoded = my_js8a%decoded + my_js8b%decoded + my_js8c%decoded + my_js8d%decoded
  write(*,1010) nsynced,ndecoded
1010 format('<DecodeFinished>',2i4)
  call flush(6)
  return

contains

  subroutine js8_decoded (sync,snr,dt,freq,decoded,nap,qual,submode)
    implicit none

    real, intent(in) :: sync
    integer, intent(in) :: snr
    real, intent(in) :: dt
    real, intent(in) :: freq
    character(len=37), intent(in) :: decoded
    character c1*12,c2*12,g2*4,w*4
    integer i0,i1,i2,i3,i4,i5,n30,nwrap
    integer, intent(in) :: nap 
    real, intent(in) :: qual 
    integer, intent(in) :: submode
    character*3 m
    character*2 annot
    character*37 decoded0
    logical isgrid4,first,b0,b1,b2
    data first/.true./
    save

    isgrid4(w)=(len_trim(w).eq.4 .and.                                        &
         ichar(w(1:1)).ge.ichar('A') .and. ichar(w(1:1)).le.ichar('R') .and.  &
         ichar(w(2:2)).ge.ichar('A') .and. ichar(w(2:2)).le.ichar('R') .and.  &
         ichar(w(3:3)).ge.ichar('0') .and. ichar(w(3:3)).le.ichar('9') .and.  &
         ichar(w(4:4)).ge.ichar('0') .and. ichar(w(4:4)).le.ichar('9'))

    if(first) then
       c2fox='            '
       g2fox='    '
       nsnrfox=-99
       nfreqfox=-99
       n30z=0
       nwrap=0
       nfox=0
       first=.false.
    endif
    
    decoded0=decoded

    annot='  ' 
    if(nap.ne.0) then
       write(annot,'(a1,i1)') 'a',nap
       if(qual.lt.0.17) decoded0(22:22)='?'
    endif


    m = ' ~ '
    if(submode.eq.0) m=' A '
    if(submode.eq.1) m=' B '
    if(submode.eq.2) m=' C '
    if(submode.eq.3) m=' D '


    i0=index(decoded0,';')
    if(i0.le.0) write(*,1000) params%nutc,snr,dt,nint(freq),m,decoded0(1:22),annot
1000 format(i6.6,i4,f5.1,i5,a3,1x,a22,1x,a2)
    if(i0.gt.0) write(*,1001) params%nutc,snr,dt,nint(freq),m,decoded0
1001 format(i6.6,i4,f5.1,i5,a3,1x,a37)

    i1=index(decoded0,' ')
    i2=i1 + index(decoded0(i1+1:),' ')
    i3=i2 + index(decoded0(i2+1:),' ')
    if(i1.ge.3 .and. i2.ge.7 .and. i3.ge.10) then
       c1=decoded0(1:i1-1)//'            '
       c2=decoded0(i1+1:i2-1)
       g2=decoded0(i2+1:i3-1)
       b0=c1.eq.mycall
       if(c1(1:3).eq.'DE ' .and. index(c2,'/').ge.2) b0=.true.
       if(len(trim(c1)).ne.len(trim(mycall))) then
          i4=index(trim(c1),trim(mycall))
          i5=index(trim(mycall),trim(c1))
          if(i4.ge.1 .or. i5.ge.1) b0=.true.
       endif
       b1=i3-i2.eq.5 .and. isgrid4(g2)
       b2=i3-i2.eq.1
       if(b0 .and. (b1.or.b2) .and. nint(freq).ge.1000) then
          n=params%nutc
          n30=(3600*(n/10000) + 60*mod((n/100),100) + mod(n,100))/30
          if(n30.lt.n30z) nwrap=nwrap+5760    !New UTC day, handle the wrap
          n30z=n30
          n30=n30+nwrap
          nfox=nfox+1
          c2fox(nfox)=c2
          g2fox(nfox)=g2
          nsnrfox(nfox)=snr
          nfreqfox(nfox)=nint(freq)
          n30fox(nfox)=n30
       endif
    endif
    
    call flush(6)

    return
  end subroutine js8_decoded

  subroutine js8a_decoded (this,sync,snr,dt,freq,decoded,nap,qual)
    use ft8_decode
    implicit none

    class(ft8_decoder), intent(inout) :: this
    real, intent(in) :: sync
    integer, intent(in) :: snr
    real, intent(in) :: dt
    real, intent(in) :: freq
    character(len=37), intent(in) :: decoded
    integer, intent(in) :: nap 
    real, intent(in) :: qual 
    save

    call js8_decoded(sync, snr, dt, freq, decoded, nap, qual, 0)

    select type(this)
    type is (counting_ft8_decoder)
       this%decoded = this%decoded + 1
    end select

    return
  end subroutine js8a_decoded

  subroutine js8b_decoded (this,sync,snr,dt,freq,decoded,nap,qual)
    use js8b_decode
    implicit none

    class(js8b_decoder), intent(inout) :: this
    real, intent(in) :: sync
    integer, intent(in) :: snr
    real, intent(in) :: dt
    real, intent(in) :: freq
    character(len=37), intent(in) :: decoded
    integer, intent(in) :: nap 
    real, intent(in) :: qual 
    save
    
    call js8_decoded(sync, snr, dt, freq, decoded, nap, qual, 1)

    select type(this)
    type is (counting_js8b_decoder)
       this%decoded = this%decoded + 1
    end select

    return
  end subroutine js8b_decoded

  subroutine js8c_decoded (this,sync,snr,dt,freq,decoded,nap,qual)
    use js8c_decode
    implicit none

    class(js8c_decoder), intent(inout) :: this
    real, intent(in) :: sync
    integer, intent(in) :: snr
    real, intent(in) :: dt
    real, intent(in) :: freq
    character(len=37), intent(in) :: decoded
    integer, intent(in) :: nap 
    real, intent(in) :: qual 
    save

    call js8_decoded(sync, snr, dt, freq, decoded, nap, qual, 2)

    select type(this)
    type is (counting_js8c_decoder)
       this%decoded = this%decoded + 1
    end select

    return
  end subroutine js8c_decoded

  subroutine js8d_decoded (this,sync,snr,dt,freq,decoded,nap,qual)
    use js8d_decode
    implicit none

    class(js8d_decoder), intent(inout) :: this
    real, intent(in) :: sync
    integer, intent(in) :: snr
    real, intent(in) :: dt
    real, intent(in) :: freq
    character(len=37), intent(in) :: decoded
    integer, intent(in) :: nap 
    real, intent(in) :: qual 
    save

    call js8_decoded(sync, snr, dt, freq, decoded, nap, qual, 3)

    select type(this)
    type is (counting_js8d_decoder)
       this%decoded = this%decoded + 1
    end select

    return
  end subroutine js8d_decoded

end subroutine multimode_decoder
