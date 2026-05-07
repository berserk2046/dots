" [Configure]
syntax on
set number
set shiftwidth=4
set tabstop=4
set noswapfile
set nobackup
set clipboard+=unnamedplus
set encoding=utf-8


" [Plugins]
call plug#begin()
Plug 'jiangmiao/auto-pairs'
Plug 'vim-airline/vim-airline'
call plug#end()

" [Keybinds]
inoremap lkj <ESC>

" [Compile And Run]
autocmd filetype c nnoremap <F5> :w <bar> !tcc % -Wall -O3 -o %:r<CR>
autocmd filetype cpp nnoremap <F6> :w <bar> !g++ % -o %:r<CR>
