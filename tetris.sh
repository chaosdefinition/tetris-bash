#!/bin/bash

# tetris-bash - Tetris written in Shell Script (Bash)
# Copyright (c) 2015 Chaos Shen
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.



############################# Data area ########################################

# Width and height
rows=20
cols=10
if [[ `tput lines` -lt $rows || `tput cols` -lt $(( $cols * 2 + 12 )) ]]; then
	echo "$0: the size of this terminal is too small to run this game"
	exit 1
fi

# Initialize game map
for (( i = 0; i < $rows; ++i )); do
	for (( j = 0; j < $cols; ++j )); do
		map[ $(( $cols * i + j )) ]=0
	done
done

# Pattern array of all blocks
blocks=(
	# S
	0 1 0 0 0 1 1 0 0 0 1 0 0 0 0 0
	0 1 1 0 1 1 0 0 0 0 0 0 0 0 0 0
	0 1 0 0 0 1 1 0 0 0 1 0 0 0 0 0
	0 1 1 0 1 1 0 0 0 0 0 0 0 0 0 0

	# Z
	0 0 1 0 0 1 1 0 0 1 0 0 0 0 0 0
	0 1 1 0 0 0 1 1 0 0 0 0 0 0 0 0
	0 0 1 0 0 1 1 0 0 1 0 0 0 0 0 0
	0 1 1 0 0 0 1 1 0 0 0 0 0 0 0 0

	# L
	0 1 0 0 0 1 0 0 0 1 1 0 0 0 0 0
	0 0 1 0 1 1 1 0 0 0 0 0 0 0 0 0
	1 1 0 0 0 1 0 0 0 1 0 0 0 0 0 0
	0 0 0 0 1 1 1 0 1 0 0 0 0 0 0 0

	# J
	0 0 1 0 0 0 1 0 0 1 1 0 0 0 0 0
	0 1 1 1 0 0 0 1 0 0 0 0 0 0 0 0
	0 0 1 1 0 0 1 0 0 0 1 0 0 0 0 0
	0 0 0 0 0 1 0 0 0 1 1 1 0 0 0 0

	# I
	0 0 0 0 1 1 1 1 0 0 0 0 0 0 0 0
	0 1 0 0 0 1 0 0 0 1 0 0 0 1 0 0
	0 0 0 0 1 1 1 1 0 0 0 0 0 0 0 0
	0 1 0 0 0 1 0 0 0 1 0 0 0 1 0 0

	# O
	0 1 1 0 0 1 1 0 0 0 0 0 0 0 0 0
	0 1 1 0 0 1 1 0 0 0 0 0 0 0 0 0
	0 1 1 0 0 1 1 0 0 0 0 0 0 0 0 0
	0 1 1 0 0 1 1 0 0 0 0 0 0 0 0 0

	# T
	0 0 0 0 1 1 1 0 0 1 0 0 0 0 0 0
	0 1 0 0 0 1 1 0 0 1 0 0 0 0 0 0
	0 1 0 0 1 1 1 0 0 0 0 0 0 0 0 0
	0 1 0 0 1 1 0 0 0 1 0 0 0 0 0 0
)

# Current block and next block information
current=(
	0 0 0 0
	0 0 0 0
	0 0 0 0
	0 0 0 0
)
current_num=0
current_color=0
next=(
	0 0 0 0
	0 0 0 0
	0 0 0 0
	0 0 0 0
)
next_num=0
next_color=0

# Initial coordinate of block in map
row=0
col=$(( ($cols - 4) / 2 ))

# Initial speed
speed=0

# Keyboard control strings
esc=`echo -en "\e"`
up=`echo -en "[A"`
down=`echo -en "[B"`
left=`echo -en "[D"`
right=`echo -en "[C"`

############################# Shell operations #################################

# Save terminal screen
function save_screen {
	echo -en "\e[?47h"
}

# Reload terminal screen
function restore_screen {
	echo -en "\e[?47l"
}

# Restore previous environment and exit
#
# $1: message to show before exit
function restore_environment {
	restore_screen
	stty sane
	setterm -cursor on
	echo $1
	exit 0
}

# Init game environment
function init_environment {
	save_screen
	setterm -cursor off
	trap "restore_environment 'Game interrupted.'" SIGINT SIGQUIT
}

# Move cursor to (row, col)
#
# $1: row number ranging from 1 to `tputs lines`
# $2: column number ranging from 1 to `tputs cols`
function move_to_coordinate {
	echo -en "\e[$1;$2f"
}

# Move cursor to map(row, col)
#
# $1: row number ranging from 0 to $(( $rows - 1 ))
# $2: column number ranging from 0 to $(( $cols - 1 ))
function move_to {
	move_to_coordinate $(( $1 + 2 )) $(( $2 * 2 + 2 ))
}

############################# Printing methods #################################

# Print a square using specified color
#
# $1: color ranging from 1 to 7
function print_square {
	echo -en "\e[0;$(( $1 + 30 ));$(( $1 + 40 ))m  \e[m"
}

# Print a square using background color
function print_background_square {
	echo -en "\e[0;30;40m  \e[m"
}

# Print a string using background color
#
# $1: a string
function print_background_char {
	echo -en "\e[1;37;40m$1\e[m"
}

# Print a block
#
# $1: row number ranging from 0 to $(( $rows - 1 ))
# $2: column number ranging from 0 to $(( $cols - 1 ))
# $3: color
# $4: pattern array
function print_block {
	local i=0
	local j=0
	for (( i = 0; i < 4; ++i )); do
		for (( j = 0; j < 4; ++j )); do
			move_to $(( $1 + i )) $(( $2 + j ))
			if (( $4[ 4 * i + j ] == 1 )); then
				print_square $3
			else
				print_background_square
			fi
		done
	done
}

# Print the next block
function print_next_block {
	print_block 0 $(( $cols + 1 )) $next_color next
}

# Print the whole map
function print_map {
	local i=0
	local j=0
	for (( i = 0; i < $rows; ++i )); do
		for (( j = 0; j < $cols; ++j )); do
			if (( ${map[ $cols * i + j ]} == 0 )); then
				print_background_square
			else
				print_square $(( ${map[ $cols * i + j ]} ))
			fi
		done
	done
}

# Printing method invoked after block rotates
function print_up {
	local i=0
	local j=0
	for (( i = 0; i < 4; ++i )); do
		if (( $row + i >= $rows )); then
			continue
		fi
		for (( j = 0; j < 4; ++j )); do
			if (( $col + j < 0 || $col + j >= $cols )); then
				continue
			fi
			move_to $(( $row + i )) $(( $col + j ))
			if (( ${current[ 4 * i + j ]} != 0 )); then
				print_square $current_color
			else
				if (( ${map[ $cols * ($row + i) + $col + j ]} != 0 )); then
					print_square $(( ${map[ $cols * ($row + i) + $col + j ]} ))
				else
					print_background_square
				fi
			fi
		done
	done
}

# Printing method invoked after block falls down to surface
#
# $1: distance to fall
function print_down {
	local i=0
	local j=0
	for (( i = 0; i < 4; ++i )); do
		if (( $row + i >= $rows )); then
			continue
		fi
		for (( j = 0; j < 4; ++j )); do
			if (( $col + j < 0 || $col + j >= $cols )); then
				continue
			fi
			if (( ${map[ $cols * ($row + i) + $col + j ]} == 0 )); then
				move_to $(( $row + i )) $(( $col + j ))
				print_background_square
			fi
		done
	done

	(( row += $1 ))
	for (( i = 0; i < 4; ++i )); do
		if (( $row + i >= $rows )); then
			continue
		fi
		for (( j = 0; j < 4; ++j )); do
			if (( $col + j < 0 || $col + j >= $cols )); then
				continue
			fi
			move_to $(( $row + i )) $(( $col + j ))
			if (( ${current[ 4 * i + j ]} != 0 )); then
				print_square $current_color
			else
				if (( ${map[ $cols * ($row + i) + $col + j ]} != 0 )); then
					print_square $(( ${map[ $cols * ($row + i) + $col + j ]} ))
				else
					print_background_square
				fi
			fi
		done
	done
}

# Printing method invoked after block moves 1 square horizontally
#
# $1: 0 if move to right, 1 if move to right
function print_horizontal {
	local i=0
	local j=0

	for (( i = 0; i < 4; ++i )); do
		if (( $row + i >= $rows )); then
			continue
		fi
		for (( j = 0; j < 4; ++j )); do
			if (( $col + j < 0 || $col + j >= $cols )); then
				continue
			fi
			move_to $(( $row + i )) $(( $col + j ))
			if (( ${current[ 4 * i + j ]} != 0 )); then
				print_square $current_color
			else
				if (( ${map[ $cols * ($row + i) + $col + j ]} != 0 )); then
					print_square $(( ${map[ $cols * ($row + i) + $col + j ]} ))
				else
					print_background_square
				fi
			fi
		done
		j=$(( $1 == 0 ? $col + 4 : $col - 1 ))
		if (( $j >= 0 && $j < $cols && ${map[ $cols * ($row + i) + $j ]} == 0 )); then
			move_to $(( $row + i )) $j
			print_background_square
		fi
	done
}

############################# Keyboard control #################################

# Stuffs to do when up key is hit
function do_on_key_up {
	local i=0
	local j=0

	rotated=$(( $current_num % 4 < 3 ? $current_num + 1 : $current_num - 3 ))
	for (( i = 0; i < 4; ++i )); do
		for (( j = 0; j < 4; ++j )); do
			if (( ${blocks[ 16 * $rotated + 4 * i + j ]} == 1 )); then
				if (( $row + i >= $rows || $col + j < 0 || $col + j >= $cols )); then
					return
				fi
				if (( ${map[ $cols * ($row + i) + $col + j ]} != 0 )); then
					return
				fi
			fi
		done
	done

	current_num=$rotated
	for (( i = 0; i < 16; ++i )); do
		current[ $i ]=$(( ${blocks[ 16 * $rotated + i ]} ))
	done
	print_up
}

# Stuffs to do when down key is hit
function do_on_key_down {
	calculate_distance
	print_down $dist
}

# Stuffs to do when left key is hit
function do_on_key_left {
	local i=0
	local j=0

	for (( i = 0; i < 4; ++i )); do
		for (( j = 0; j < 4; ++j )); do
			if (( ${current[ 4 * j + i ]} == 1 )); then
				if (( $col + i - 1 < 0 )); then
					break
				fi
				if (( ${map[ $cols * ($row + j) + $col + i - 1 ]} != 0 )); then
					break
				fi
			fi
		done
		if (( j != 4 )); then
			break
		fi
	done
	if (( i == 4 )); then
		(( --col ))
		print_horizontal 0
	fi
}

# Stuffs to do when right key is hit
function do_on_key_right {
	local i=0
	local j=0

	for (( i = 0; i < 4; ++i )); do
		for (( j = 0; j < 4; ++j )); do
			if (( ${current[ 4 * j + 3 - i ]} == 1 )); then
				if (( $col + 4 - i >= $cols )); then
					break
				fi
				if (( ${map[ $cols * ($row + j) + $col + 4 - i ]} != 0 )); then
					break
				fi
			fi
		done
		if (( j != 4 )); then
			break
		fi
	done
	if (( i == 4 )); then
		(( ++col ))
		print_horizontal 1
	fi
}

# Check if keyboard is hit and respond to specified keys
function check_keyboard_hit {
	read -s -n 1 -t 0.3
	case $REPLY in
		$esc )
			read -s -n 2 -t 0.001
			case $REPLY in
				$up )
					do_on_key_up
					;;

				$down )
					do_on_key_down
					;;

				$left )
					do_on_key_left
					;;

				$right )
					do_on_key_right
					;;

				* )
					;;
			esac
			;;

		* )
			;;
	esac
}

############################# Game logics ######################################

# Calculate the distance between current block and surface
function calculate_distance {
	local i=0
	local j=0
	local k=0

	dist=$rows
	for (( i = 0; i < 4; ++i )); do
		for (( j = 0; j < 4; ++j )); do
			if (( ${current[ 12 - 4 * j + i ]} == 1 )); then
				break
			fi
		done
		if (( j == 4 )); then
			continue
		fi
		for (( k = $row + 4 - j; k < $rows; ++k )); do
			if (( ${map[ 4 * k + col + i ]} != 0 )); then
				break
			fi
		done
		dist=$(( k + j - $row - 4 < $dist ? k + j - $row - 4 : $dist ))
	done
}

# Generate a new block with random shape and color
#
# $1: name of block number
# $2: name of color number
# $3: name of pattern array
function generate_new_block {
	let "$1=$(( $RANDOM % 28 ))"
	let "$2=$(( $RANDOM % 7 + 1 ))"
	for (( i = 0; i < 4; ++i )); do
		for (( j = 0; j < 4; ++j )); do
			let "$3[ $(( 4 * i + j )) ]=${blocks[ $(( 16 * $1 + 4 * i + j )) ]}"
		done
	done
}

############################# Init and main ####################################

# Init the game
function init {
	local i=0
	local j=0

	init_environment

	move_to_coordinate 1 1
	print_background_char "+"
	for (( i = 0; i < $cols; ++i )); do
		print_background_char "--"
	done
	print_background_char "+\n"
	for (( i = 0; i < $rows; ++i )); do
		print_background_char "|"
		for (( j = 0; j < $cols; ++j )); do
			print_background_square
		done
		print_background_char "|\n"
	done
	print_background_char "+"
	for (( i = 0; i < $cols; ++i )); do
		print_background_char "--"
	done
	print_background_char "+\n"

	move_to_coordinate 1 $(( $cols * 2 + 3 ))
	print_background_char "+--------+"
	for (( i = 0; i < 4; ++i )); do
		move_to_coordinate $(( 2 + i )) $(( $cols * 2 + 3 ))
		print_background_char "|"
		for (( j = 0; j < 4; ++j )); do
			print_background_square
		done
		print_background_char "|"
	done
	move_to_coordinate 6 $(( $cols * 2 + 3 ))
	print_background_char "+--------+"
}

# Main process
function main {
	init

	generate_new_block current_num current_color current
	generate_new_block next_num next_color next
	print_block $row $col $current_color current
	print_next_block

	while true; do
		while true; do
			start=`date +%s%N`
			while (( `date +%s%N` - $start < 1000000000 - $speed * 50000000 )); do
				check_keyboard_hit
			done
			calculate_distance
			if (( $dist > 0 )); then
				print_down 1
			else
				break
			fi
		done
		# write to map
		# decrease lines
		# if game is over, break
		# else generate new block
	done

	restore_environment "Game over!!!"
}

main
