ALIRE_DIR=/opt/alire
#export PATH=$ALIRE_DIR/bin:/opt/tkdiff:/opt/fuzz/bin:/opt/arm-gnu-toolchain/bin:/opt/gnatstudio:$PATH
export PATH=/opt/gcc-14.2.0-3-aarch64/bin:$ALIRE_DIR/bin:~/.alire/bin:/opt/tkdiff:/opt/fuzz/bin:/opt/arm-gnu-toolchain/bin:$PATH

export OS=macOS

export GIT_EXTERNAL_DIFF=tkdiff

alias v='gvim -U ide_env.vim'

function gen_lst_arm
{
    typeset elf_file
    typeset usage_msg

    usage_msg="Usage: gen_lst <elf file>"

    if [ $# != 1 ]; then
        echo $usage_msg
        return 1
    fi

    elf_file=$1
    if [ ! -f $elf_file ]; then
        echo "*** ERROR: file $elf_file does not exist"
        return 1
    fi

    rm -f $elf_file.lst

    echo "Generating $elf_file.lst ..."
    arm-none-eabi-objdump -dSstl $elf_file > $elf_file.lst

    if [ ! -f $elf_file.lst ]; then
        echo "*** ERROR: file $elf_file.lst not created"
        return 1;
    fi
}

function flash_raspberry4
{
    typeset bin_file
    typeset tty_dev
    typeset usage_msg

    usage_msg="Usage: $FUNCNAME <bin file>"

    if [ $# != 1 ]; then
        echo $usage_msg
        return 1
    fi

    bin_file=$1
    if [ ! -f $bin_file ]; then
        echo "*** ERROR: file $bin_file does not exist"
        return 1
    fi

   # Flash App image on SD card:
   cp $bin_file /Volumes/bootfs/kernel8.img
   sync
}

function my_uart {
   typeset tty_port

   if [ $# != 1 ]; then
        echo "Usage: $FUNCNAME <tty port>"
        return 1
   fi

   tty_port=$1

   #picocom -b 115200 --send-cmd="lsx -vv --xmodem --binary" --receive-cmd="lrx -vv" $tty_port
   picocom -b 115200 --send-cmd="$HOME/my-projects/uart_boot_loader/uart_boot_loader_client/bin/uart_boot_loader_client" $tty_port
}

. ~/my-projects/third-party/alire/scripts/alr-completion.bash
