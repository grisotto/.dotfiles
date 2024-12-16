call plug#begin('~/.vim/plugged')
    Plug 'tpope/vim-obsession'
    Plug 'tpope/vim-surround'
   Plug 'vimwiki/vimwiki'
    Plug 'neoclide/jsonc.vim'
    Plug 'inkarkat/vim-ReplaceWithRegister'
    Plug 'Yggdroot/indentLine'
    Plug 'ingydotnet/yaml-vim'
call plug#end()

set nocompatible
filetype plugin on

syntax on
let mapleader =" "
let maplocalleader = " "
" General
" syntax on
set number            " Show line numbers
set linebreak         " Break lines at word (requires Wrap lines)
set list
set mouse=a
" Show “invisible” characters
" set listchars=tab:▸\ ,eol:¬,trail:⋅,extends:❯,precedes:❮
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<
" Show the (partial) command as it’s being typed
set showcmd
set encoding=utf-8
" Start scrolling three lines before the horizontal window border
set scrolloff=3
set showmode
set showbreak=↪
set wrap
set formatoptions-=t
set wrapmargin=80
set colorcolumn=0
set showmatch         " Highlight matching brace
set relativenumber
set undofile
set ruler

hi clear SpellBad
hi SpellBad cterm=underline,bold
" set complete+=kspell
set complete+=k
set visualbell        " Use visual bell (no beeping)
set t_vb=
set noerrorbells
" Disable error bells
set noerrorbells
" Don’t reset cursor to start of line when moving around.
set nostartofline
" Open new split panes to right and bottom, which feels more natural than Vim’s default:
set splitbelow
set splitright
set foldmethod=syntax
set hlsearch          " Highlight all search results
set smartcase         " Enable smart-case search
set gdefault
set ignorecase        " Always case-insensitive
set incsearch         " Searches for strings incrementally
nnoremap <leader><space><space> :noh<cr>
nnoremap <tab> %
vnoremap <tab> %

nnoremap j gj
nnoremap k gk

inoremap <F1> <ESC>
nnoremap <F1> <ESC>
vnoremap <F1> <ESC>

nnoremap <leader>q gqip

inoremap jj <ESC>

""" PANELS
""" CLOSE PANEL
noremap <leader>q :q<CR>

nnoremap <leader>w <C-w>v<C-w>l
nnoremap <leader>v <C-w>s<C-w>l

""" MOVING AROUND
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

""" GO TO A SPECIFIC TAB (FROM 1 TO 9)
noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt


"strip all trailing whitespace in the current file
"nnoremap <leader>W :%s/\s\+$//<cr>:let @/=''<CR>
"Ack 
nnoremap <leader>a :Ack

"map <C-i> :bnext<CR>
"map <C-u> :bprev<CR>
"map <C-j> :tabnext<CR>
"map <C-k> :tabprevious<CR>
map ; :
"this is the best way haha
set laststatus=2
set backspace=2

let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

"let &t_SI = "\<Esc>]50;CursorShape=1\x7"
"let &t_SR = "\<Esc>]50;CursorShape=2\x7"
"let &t_EI = "\<Esc>]50;CursorShape=0\x7"

set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
filetype plugin on

syntax enable
set mouse=a

hi Search cterm=NONE ctermfg=grey ctermbg=blue

set ignorecase

set splitright
set splitbelow

set number
let g:molokai_original = 1
set background=dark

set autoindent
set cindent



set timeoutlen=1000 ttimeoutlen=0
set textwidth=200

set clipboard+=unnamed

" " Copy to clipboard
vnoremap  <leader>y  "zy
nnoremap  <leader>Y  "zyg_
nnoremap  <leader>y  "zy
nnoremap  <leader>yy  "zyy

" " Paste from clipboard
nnoremap <leader>p "zp
nnoremap <leader>P "zP
vnoremap <leader>p "zp
vnoremap <leader>P "zP


nnoremap <tab> %
vnoremap <tab> %
cmap w!! w !sudo tee > /dev/null %

" persistent undo
if has("persistent_undo")
     set undodir=~/_undodir/
     set undofile
endif
noremap <leader>0 :tabnew<CR>:e ~/.vimTodo<CR>

" Identation for yaml files
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab

" GVim
let g:indentLine_color_gui = '#A4E57E'

" Background (Vim, GVim)
let g:indentLine_bgcolor_term = 202
" let g:indentLine_bgcolor_gui = '#ffae00'
let g:indentLine_char_list = ['|', '¦', '┆', '┊']
colorscheme darkblue
set guifont=OpenDyslexicMono:h14:cANSI:qDRAFT
"sessao
"Manda um :Obsess para ele criar o Session e salvar lá antes de fechar o gvim 
"altere o atalho para -S Session.vim
"
"vimwiki - precisa migrar primeiro
"let g:vimwiki_list = [{'path': '~/vimwiki/',
"                      \ 'syntax': 'markdown', 'ext': '.md'}]

"vimwiki folding 
let g:vimwiki_folding='custom'
