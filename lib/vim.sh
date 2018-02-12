#!/usr/bin/env bash
#
# VIM FUNCTIONS
#

export VIMRC=$HOME/.vimrc

if [[ ! -f ${VIMRC} ]]; then
    cp ${MOON_USR}/vim/vimrc ${VIMRC}
fi

# If you are editing an empty file, vim can automatically create the file from
# a known template based on the file extension.
#
VIM_TEMPLATE_EXTENSIONS=(py rb sh)

for extension in ${VIM_TEMPLATE_EXTENSIONS}; do
    [[ $(grep -c template\.${extension} ${VIMRC} || true) == 0 ]] \
        && echo "autocmd BufNewFile *.${extension} 0r ${MOON_USR}/vim/template.${extension}" >> ${VIMRC} \
        || true
done

