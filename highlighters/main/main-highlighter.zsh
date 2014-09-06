#!/usr/bin/env zsh
# -------------------------------------------------------------------------------------------------
# Copyright (c) 2010-2011 zsh-syntax-highlighting contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this list of conditions
#    and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice, this list of
#    conditions and the following disclaimer in the documentation and/or other materials provided
#    with the distribution.
#  * Neither the name of the zsh-syntax-highlighting contributors nor the names of its contributors
#    may be used to endorse or promote products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

# Whether the highlighter should be called or not.
_zsh_highlight_main_highlighter_predicate()
{
  _zsh_highlight_buffer_modified
}

# Main syntax highlighting function.
_zsh_highlight_main_highlighter()
{
  emulate -L zsh
  setopt localoptions extendedglob bareglobqual
  local start_pos=0 end_pos highlight_glob=true new_expression=true arg style sudo=false sudo_arg=false
  typeset -a ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR
  typeset -a ZSH_HIGHLIGHT_TOKENS_PRECOMMANDS
  typeset -a ZSH_HIGHLIGHT_TOKENS_FOLLOWED_BY_COMMANDS
  region_highlight=()

  ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR=(
    '|' '||' ';' '&' '&&'
  )
  ZSH_HIGHLIGHT_TOKENS_PRECOMMANDS=(
    'builtin' 'command' 'exec' 'nocorrect' 'noglob'
  )
  # Tokens that are always immediately followed by a command.
  ZSH_HIGHLIGHT_TOKENS_FOLLOWED_BY_COMMANDS=(
    $ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR $ZSH_HIGHLIGHT_TOKENS_PRECOMMANDS
  )

  local highlight_default highlight_unknown_token highlight_reserved_word \
	highlight_alias highlight_builtin highlight_function highlight_command \
	highlight_precommand highlight_commandseparator highlight_hashed_command \
	highlight_path highlight_path_prefix highlight_path_approx \
	highlight_globbing highlight_history_expansion \
	highlight_single_hyphen_option highlight_double_hyphen_option \
	highlight_back_quoted_argument highlight_single_quoted_argument \
	highlight_double_quoted_argument highlight_dollar_double_quoted_argument \
	highlight_back_double_quoted_argument highlight_assign

  # Define default styles.
  zstyle -s ':zsh-syntax-highlighting:main:' default                       highlight_default                       || highlight_default='none'
  zstyle -s ':zsh-syntax-highlighting:main:' unknown-token                 highlight_unknown_token                 || highlight_unknown_token='fg=red,bold'
  zstyle -s ':zsh-syntax-highlighting:main:' reserved-word                 highlight_reserved_word                 || highlight_reserved_word='fg=yellow'
  zstyle -s ':zsh-syntax-highlighting:main:' alias                         highlight_alias                         || highlight_alias='fg=green'
  zstyle -s ':zsh-syntax-highlighting:main:' builtin                       highlight_builtin                       || highlight_builtin='fg=green'
  zstyle -s ':zsh-syntax-highlighting:main:' function                      highlight_function                      || highlight_function='fg=green'
  zstyle -s ':zsh-syntax-highlighting:main:' command                       highlight_command                       || highlight_command='fg=green'
  zstyle -s ':zsh-syntax-highlighting:main:' precommand                    highlight_precommand                    || highlight_precommand='fg=green,underline'
  zstyle -s ':zsh-syntax-highlighting:main:' commandseparator              highlight_commandseparator              || highlight_commandseparator='none'
  zstyle -s ':zsh-syntax-highlighting:main:' hashed-command                highlight_hashed_command                || highlight_hashed_command='fg=green'
  zstyle -s ':zsh-syntax-highlighting:main:' path                          highlight_path                          || highlight_path='underline'
  zstyle -s ':zsh-syntax-highlighting:main:' path_prefix                   highlight_path_prefix                   || highlight_path_prefix='underline'
  zstyle -s ':zsh-syntax-highlighting:main:' path_approx                   highlight_path_approx                   || highlight_path_approx='fg=yellow,underline'
  zstyle -s ':zsh-syntax-highlighting:main:' globbing                      highlight_globbing                      || highlight_globbing='fg=blue'
  zstyle -s ':zsh-syntax-highlighting:main:' history-expansion             highlight_history_expansion             || highlight_history_expansion='fg=blue'
  zstyle -s ':zsh-syntax-highlighting:main:' single-hyphen-option          highlight_single_hyphen_option          || highlight_single_hyphen_option='none'
  zstyle -s ':zsh-syntax-highlighting:main:' double-hyphen-option          highlight_double_hyphen_option          || highlight_double_hyphen_option='none'
  zstyle -s ':zsh-syntax-highlighting:main:' back-quoted-argument          highlight_back_quoted_argument          || highlight_back_quoted_argument='none'
  zstyle -s ':zsh-syntax-highlighting:main:' single-quoted-argument        highlight_single_quoted_argument        || highlight_single_quoted_argument='fg=yellow'
  zstyle -s ':zsh-syntax-highlighting:main:' double-quoted-argument        highlight_double_quoted_argument        || highlight_double_quoted_argument='fg=yellow'
  zstyle -s ':zsh-syntax-highlighting:main:' dollar-double-quoted-argument highlight_dollar_double_quoted_argument || highlight_dollar_double_quoted_argument='fg=cyan'
  zstyle -s ':zsh-syntax-highlighting:main:' back-double-quoted-argument   highlight_back_double_quoted_argument   || highlight_back_double_quoted_argument='fg=cyan'
  zstyle -s ':zsh-syntax-highlighting:main:' assign                        highlight_assign                        || highlight_assign='none'

  for arg in ${(z)BUFFER}; do
    local substr_color=0
    local style_override=""
    [[ $start_pos -eq 0 && $arg = 'noglob' ]] && highlight_glob=false
    ((start_pos+=${#BUFFER[$start_pos+1,-1]}-${#${BUFFER[$start_pos+1,-1]##[[:space:]]#}}))
    ((end_pos=$start_pos+${#arg}))
    # Parse the sudo command line
    if $sudo; then
      case "$arg" in
        # Flag that requires an argument
        '-'[Cgprtu]) sudo_arg=true;;
        # This prevents misbehavior with sudo -u -otherargument
        '-'*)        sudo_arg=false;;
        *)           if $sudo_arg; then
                       sudo_arg=false
                     else
                       sudo=false
                       new_expression=true
                     fi
                     ;;
      esac
    fi
    if $new_expression; then
      new_expression=false
     if [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_PRECOMMANDS:#"$arg"} ]]; then
      style=$highlight_precommand
     elif [[ "$arg" = "sudo" ]]; then
      style=$highlight_precommand
      sudo=true
     else
      res=$(LC_ALL=C builtin type -w $arg 2>/dev/null)
      case $res in
        *': reserved')  style=$highlight_reserved_word;;
        *': alias')     style=$highlight_alias
                        local aliased_command="${"$(alias -- $arg)"#*=}"
                        [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_FOLLOWED_BY_COMMANDS:#"$aliased_command"} && -z ${(M)ZSH_HIGHLIGHT_TOKENS_FOLLOWED_BY_COMMANDS:#"$arg"} ]] && ZSH_HIGHLIGHT_TOKENS_FOLLOWED_BY_COMMANDS+=($arg)
                        ;;
        *': builtin')   style=$highlight_builtin;;
        *': function')  style=$highlight_function;;
        *': command')   style=$highlight_command;;
        *': hashed')    style=$highlight_hashed_command;;
        *)              if _zsh_highlight_main_highlighter_check_assign; then
                          style=$highlight_assign
                          new_expression=true
                        elif _zsh_highlight_main_highlighter_check_path; then
                          style=$highlight_path
                        elif [[ $arg[0,1] == $histchars[0,1] || $arg[0,1] == $histchars[2,2] ]]; then
                          style=$highlight_history_expansion
                        else
                          style=$highlight_unknown_token
                        fi
                        ;;
      esac
     fi
    else
      case $arg in
        '--'*)   style=$highlight_double_hyphen_option;;
        '-'*)    style=$highlight_single_hyphen_option;;
        "'"*"'") style=$highlight_single_quoted_argument;;
        '"'*'"') style=$highlight_double_quoted_argument
                 region_highlight+=("$start_pos $end_pos $style")
                 _zsh_highlight_main_highlighter_highlight_string
                 substr_color=1
                 ;;
        '`'*'`') style=$highlight_back_quoted_argument;;
        *"*"*)   $highlight_glob && style=$highlight_globbing || style=$highlight_default;;
        *)       if _zsh_highlight_main_highlighter_check_path; then
                   style=$highlight_path
                 elif [[ $arg[1] == $histchars[1] || $arg[1] == $histchars[2] ]]; then
                   style=$highlight_history_expansion
                 elif [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_COMMANDSEPARATOR:#"$arg"} ]]; then
                   style=$highlight_commandseparator
                 else
                   style=$highlight_default
                 fi
                 ;;
      esac
    fi
    # if a style_override was set (eg in _zsh_highlight_main_highlighter_check_path), use it
    [[ -n $style_override ]] && style=$highlight-$style_override
    [[ $substr_color = 0 ]] && region_highlight+=("$start_pos $end_pos $style")
    [[ -n ${(M)ZSH_HIGHLIGHT_TOKENS_FOLLOWED_BY_COMMANDS:#"$arg"} ]] && new_expression=true
    start_pos=$end_pos
  done
}

# Check if the argument is variable assignment
_zsh_highlight_main_highlighter_check_assign()
{
    setopt localoptions extended_glob
    [[ $arg == [[:alpha:]_][[:alnum:]_]#(|\[*\])=* ]]
}

# Check if the argument is a path.
_zsh_highlight_main_highlighter_check_path()
{
  setopt localoptions nonomatch
  local expanded_path; : ${expanded_path:=${(Q)~arg}}
  [[ -z $expanded_path ]] && return 1
  [[ -e $expanded_path ]] && return 0
  # Search the path in CDPATH
  local cdpath_dir
  for cdpath_dir in $cdpath ; do
    [[ -e "$cdpath_dir/$expanded_path" ]] && return 0
  done
  [[ ! -e ${expanded_path:h} ]] && return 1
  if [[ ${BUFFER[1]} != "-" && ${#BUFFER} == $end_pos ]]; then
    local -a tmp
    # got a path prefix?
    tmp=( ${expanded_path}*(N) )
    (( $#tmp > 0 )) && style_override=path_prefix && return 0
    # or maybe an approximate path?
    tmp=( (#a1)${expanded_path}*(N) )
    (( $#tmp > 0 )) && style_override=path_approx && return 0
  fi
  return 1
}

# Highlight special chars inside double-quoted strings
_zsh_highlight_main_highlighter_highlight_string()
{
  setopt localoptions noksharrays
  local i j k style varflag
  # Starting quote is at 1, so start parsing at offset 2 in the string.
  for (( i = 2 ; i < end_pos - start_pos ; i += 1 )) ; do
    (( j = i + start_pos - 1 ))
    (( k = j + 1 ))
    case "$arg[$i]" in
      '$' ) style=$highlight_dollar_double_quoted_argument
            (( varflag = 1))
            ;;
      "\\") style=$highlight_back_double_quoted_argument
            for (( c = i + 1 ; c < end_pos - start_pos ; c += 1 )); do
              [[ "$arg[$c]" != ([0-9,xX,a-f,A-F]) ]] && break
            done
            AA=$arg[$i+1,$c-1]
            # Matching for HEX and OCT values like \0xA6, \xA6 or \012
            if [[ "$AA" =~ "^(0*(x|X)[0-9,a-f,A-F]{1,2})" || "$AA" =~ "^(0[0-7]{1,3})" ]];then
              (( k += $#MATCH ))
              (( i += $#MATCH ))
            else
              (( k += 1 )) # Color following char too.
              (( i += 1 )) # Skip parsing the escaped char.
            fi
              (( varflag = 0 )) # End of variable
            ;;
      ([^a-zA-Z0-9_]))
            (( varflag = 0 )) # End of variable
            continue
            ;;
      *) [[ $varflag -eq 0 ]] && continue ;;

    esac
    region_highlight+=("$j $k $style")
  done
}
