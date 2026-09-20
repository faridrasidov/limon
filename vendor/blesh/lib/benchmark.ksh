#!/usr/bin/env ksh

#!/bin/bash

_ble_measure_target=ksh
if ! type _ble_util_print &>/dev/null; then
  _ble_util_unlocal() { unset -v "$@"; }
  function _ble_util_print { printf '%s\n' "$1"; }
  function _ble_util_print_lines { printf '%s\n' "$@"; }
fi

function _ble_measure__loop {
  # Note: ksh requires to quote ;
  eval "function _target { ${2:+"$2; "}return 0; }"
  typeset __ble_i __ble_n=$1
  for ((__ble_i=0;__ble_i<__ble_n;__ble_i++)); do
    _target
  done
}

## @fn _ble_measure__time n command
##   @param[in] n command
##   @var[out] ret
##     計測にかかった総時間を μs 単位で返します。
if ((BASH_VERSINFO[0]>=5)) ||
     { [[ ${ZSH_VERSION-} ]] && zmodload zsh/datetime &>/dev/null && [[ ${EPOCHREALTIME-} ]]; } ||
     [[ ${SECONDS-} == *.??? ]]
then
  ## @fn _ble_measure__get_realtime
  ##   @var[out] ret
  if [[ ${EPOCHREALTIME-} ]]; then
    _ble_measure_resolution=1 # [usec]
    _ble_measure__get_realtime() {
      typeset LC_ALL= LC_NUMERIC=C
      ret=$EPOCHREALTIME
    }
  else
    # Note: ksh does not have "local"-equivalent for the POSIX-style functions,
    #   so we do not set the locale here.  Anyway, we do not care the
    #   interference with outer-scope variables since this script is used
    #   limitedly in ksh.
    _ble_measure_resolution=1000 # [usec]
    _ble_measure__get_realtime() {
      ret=$SECONDS
    }
  fi
  _ble_measure__time() {
    _ble_measure__get_realtime 2>/dev/null; typeset __ble_time1=$ret
    _ble_measure__loop "$1" "$2" &>/dev/null
    _ble_measure__get_realtime 2>/dev/null; typeset __ble_time2=$ret

    # convert __ble_time1 and __ble_time2 to usec
    # Note: ksh does not support empty index as ${__ble_frac::6}.
    typeset __ble_frac
    [[ $__ble_time1 == *.* ]] || __ble_time1=${__ble_time1}.
    __ble_frac=${__ble_time1##*.}000000 __ble_time1=${__ble_time1%%.*}${__ble_frac:0:6}
    [[ $__ble_time2 == *.* ]] || __ble_time2=${__ble_time2}.
    __ble_frac=${__ble_time2##*.}000000 __ble_time2=${__ble_time2%%.*}${__ble_frac:0:6}

    ((ret=__ble_time2-__ble_time1))
    ((ret==0&&(ret=_ble_measure_resolution)))
    ((ret>0))
  }
elif [[ ${ZSH_VERSION-} ]]; then
  _ble_measure_resolution=1000 # [usec]
  # [ksh incompatible code stripped]
else
  _ble_measure_resolution=1000 # [usec]
  # [ksh incompatible code stripped]
fi

_ble_measure_base= # [nsec]
_ble_measure_base_nestcost=0 # [nsec/10]
typeset -a _ble_measure_base_real
typeset -a _ble_measure_base_guess
_ble_measure_count=1 # 同じ倍率で _ble_measure_count 回計測して最小を取る。
_ble_measure_threshold=100000 # 一回の計測が threshold [usec] 以上になるようにする


## @fn _ble_measure__read_arguments_get_optarg
##   @var[in] args arg i c
##   @var[in,out] iarg
##   @var[out] optarg
_ble_measure__read_arguments_get_optarg() {
  if ((i+1<${#arg})); then
    optarg=${arg:$((i+1))}
    i=${#arg}
    return 0
  elif ((iarg<${#args[@]})); then
    optarg=${args[iarg++]}
    return 0
  else
    _ble_util_print "ble_measure: missing option argument for '-$c'."
    flags=E$flags
    return 1
  fi
}

## @fn _ble_measure__read_arguments args
##   @var[out] flags
##   @var[out] command count
_ble_measure__read_arguments() {
  typeset -a args; args=("$@")
  typeset iarg=0 optarg=
  [[ ${ZSH_VERSION-} && ! -o KSH_ARRAYS ]] && iarg=1
  while [[ ${args[iarg]} == -* ]]; do
    typeset arg=${args[iarg++]}
    case $arg in
    (--) break ;;
    (--help) flags=h$flags ;;
    (--no-print-progress) flags=V$flags ;;
    (--*)
      _ble_util_print "ble_measure: unrecognized option '$arg'."
      flags=E$flags ;;
    (-?*)
      typeset i= c= # Note: zsh prints the values with just "local i c"
      for ((i=1;i<${#arg};i++)); do
        c=${arg:$i:1}
        case $c in
        (q) flags=qV$flags ;;
        ([ca])
          [[ $c == a ]] && flags=a$flags
          _ble_measure__read_arguments_get_optarg && count=$optarg ;;
        (T)
          _ble_measure__read_arguments_get_optarg &&
            measure_threshold=$optarg ;;
        (B)
          _ble_measure__read_arguments_get_optarg &&
            __ble_base=$optarg ;;
        (*)
          _ble_util_print "ble_measure: unrecognized option '-$c'."
          flags=E$flags ;;
        esac
      done ;;
    (-)
      _ble_util_print "ble_measure: unrecognized option '$arg'."
      flags=E$flags ;;
    esac
  done
  typeset IFS=$' \t\n'
  if [[ ${ZSH_VERSION-} ]]; then
    command="${args[$iarg,-1]}"
  else
    command="${args[*]:$iarg}"
  fi
  [[ $flags != *E* ]]
}

## @fn ble_measure [-q|-ac COUNT] command
##   command を繰り返し実行する事によりその実行時間を計測します。
##   -q を指定した時、計測結果を出力しません。
##   -c COUNT を指定した時 COUNT 回計測して最小値を採用します。
##   -a COUNT を指定した時 COUNT 回計測して平均値を採用します。
##
##   @var[out] ret
##     実行時間を usec 単位で返します。
##   @var[out] nsec
##     実行時間を nsec 単位で返します。
ble_measure() {
  eval -- "${_ble_bash_POSIXLY_CORRECT_local_adjust-}"
  typeset __ble_level=${#FUNCNAME[@]} __ble_base=
  [[ ${ZSH_VERSION-} ]] && __ble_level=${#funcstack[@]}
  typeset flags= command= count=$_ble_measure_count
  typeset measure_threshold=$_ble_measure_threshold
  _ble_measure__read_arguments "$@"; typeset ext=$?
  if ((ext)); then
    eval -- "${_ble_bash_POSIXLY_CORRECT_local_leave-}"
    return "$ext"
  fi

  if [[ $flags == *h* ]]; then
    _ble_util_print_lines \
      'usage: ble_measure [-q|-ac COUNT|-TB TIME] [--] COMMAND' \
      '    Measure the time of command.' \
      '' \
      '  Options:' \
      '    -q        Do not print results to stdout.' \
      '    -a COUNT  Measure COUNT times and average.' \
      '    -c COUNT  Measure COUNT times and take minimum.' \
      '    -T TIME   Set minimal measuring time.' \
      '    -B BASE   Set base time (overhead of ble_measure).' \
      '    --        The rest arguments are treated as command.' \
      '    --help    Print this help.' \
      '' \
      '  Arguments:' \
      '    COMMAND   Command to be executed repeatedly.' \
      '' \
      '  Exit status:' \
      '    Returns 1 for the failure in measuring the time.  Returns 2 after printing' \
      '    help.  Otherwise, returns 0.'
    eval -- "${_ble_bash_POSIXLY_CORRECT_local_leave-}"
    return 2
  fi

  if [[ ! $__ble_base ]]; then
    if [[ $_ble_measure_base ]]; then
      # ble_measure/calibrate 実行済みの時
      __ble_base=$((_ble_measure_base+_ble_measure_base_nestcost*__ble_level/10))
    else
      # それ以外の時は __ble_level 毎に計測
      if [[ ! $_ble_measure_calibrate && ! ${_ble_measure_base_guess[__ble_level]} ]]; then
        if [[ ! ${_ble_measure_base_real[__ble_level+1]} ]]; then
          if [[ ${_ble_measure_target-} == ksh ]]; then
            # Note: In ksh, we cannot do recursive call with dynamic scoping,
            # so we directly call the measuring function
            _ble_measure__time 50000 ''
            ((nsec=ret*1000/50000))
          else
            typeset _ble_measure_calibrate=1
            ble_measure -qc3 -B 0 ''
            _ble_util_unlocal _ble_measure_calibrate
          fi
          _ble_measure_base_real[__ble_level+1]=$nsec
          _ble_measure_base_guess[__ble_level+1]=$nsec
        fi

        # 上の実測値は一つ上のレベル (__ble_level+1) での結果になるので現在のレベル
        # (__ble_level) の値に補正する。レベル毎の時間が chatoyancy での線形フィッ
        # トの結果に比例する仮定して補正を行う。
        #
        # linear-fit result with $f(x) = A x + B$ in chatoyancy
        #   A = 65.9818 pm 2.945 (4.463%)
        #   B = 4356.75 pm 19.97 (0.4585%)
        typeset cA=6598 cB=435675
        nsec=${_ble_measure_base_real[__ble_level+1]}
        _ble_measure_base_guess[__ble_level]=$((nsec*(cB+cA*(__ble_level-1))/(cB+cA*__ble_level)))
        _ble_util_unlocal cA cB
      fi
      __ble_base=${_ble_measure_base_guess[__ble_level]:-0}
    fi
  fi

  typeset __ble_max_n=500000
  typeset prev_n= prev_utot=
  typeset -i n
  for n in {1,10,100,1000,10000,100000}\*{1,2,5}; do
    [[ $prev_n ]] && ((n/prev_n<=10 && prev_utot*n/prev_n<measure_threshold*2/5 && n!=50000)) && continue

    typeset utot=0
    [[ $flags != *V* ]] && printf '%s (x%d)...' "$command" "$n" >&2
    if ! _ble_measure__time "$n" "$command"; then
      eval -- "${_ble_bash_POSIXLY_CORRECT_local_leave-}"
      return 1
    fi
    [[ $flags != *V* ]] && printf '\r\e[2K' >&2
    ((utot=ret,utot>=measure_threshold||n==__ble_max_n)) || continue

    prev_n=$n prev_utot=$utot
    typeset min_utot=$utot

    # 繰り返し計測して最小値 (-a の時は平均値) を採用
    if [[ $count ]]; then
      typeset sum_utot=$utot sum_count=1 i
      for ((i=2;i<=count;i++)); do
        [[ $flags != *V* ]] && printf '%s' "$command (x$n $i/$count)..." >&2
        if _ble_measure__time "$n" "$command"; then
          ((utot=ret,utot<min_utot)) && min_utot=$utot
          ((sum_utot+=utot,sum_count++))
        fi
        [[ $flags != *V* ]] && printf '\r\e[2K' >&2
      done
      if [[ $flags == *a* ]]; then
        ((utot=sum_utot/sum_count))
      else
        utot=$min_utot
      fi
    fi

    # update base if the result is shorter than base
    if ((min_utot<0x7FFFFFFFFFFFFFFF/1000)); then
      typeset __ble_real=$((min_utot*1000/n))
      [[ ${_ble_measure_base_real[__ble_level]} ]] &&
        ((__ble_real<_ble_measure_base_real[__ble_level])) &&
        _ble_measure_base_real[__ble_level]=$__ble_real
      [[ ${_ble_measure_base_guess[__ble_level]} ]] &&
        ((__ble_real<_ble_measure_base_guess[__ble_level])) &&
        _ble_measure_base_guess[__ble_level]=$__ble_real
      ((__ble_real<__ble_base)) &&
        __ble_base=$__ble_real
    fi

    typeset nsec0=$__ble_base
    if [[ $flags != *q* ]]; then
      typeset reso=$_ble_measure_resolution
      typeset awk=ble/bin/awk
      type -- "$awk" &>/dev/null || awk=awk
      typeset -x title="$command (x$n)"
      "$awk" -v utot="$utot" -v nsec0="$nsec0" -v n="$n" -v reso="$reso" '
        function genround(x, mod) { return int(x / mod + 0.5) * mod; }
        BEGIN { title = ENVIRON["title"]; printf("%12.3f usec/eval: %s\n", genround(utot / n - nsec0 / 1000, reso / 10.0 / n), title); exit }'
    fi

    typeset out
    ((out=utot/n))
    if ((n>=1000)); then
      ((nsec=utot/(n/1000)))
    else
      ((nsec=utot*1000/n))
    fi
    ((out-=nsec0/1000,nsec-=nsec0))
    ret=$out
    eval -- "${_ble_bash_POSIXLY_CORRECT_local_leave-}"
    return 0
  done
  eval -- "${_ble_bash_POSIXLY_CORRECT_local_return-}"
}
