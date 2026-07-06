call plug#begin('~/.vim/plugged')

Plug 'catppuccin/vim', {'as': 'catppuccin'}
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'dense-analysis/ale'

call plug#end()

set termguicolors
syntax enable
filetype plugin indent on
colorscheme catppuccin_mocha
set number
set relativenumber
set mouse=a
set scrolloff=8
set sidescrolloff=8

set ignorecase
set smartcase
set incsearch
set hlsearch

set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2
set smartindent
set shiftround

set cursorline
set signcolumn=yes
set colorcolumn=80
set list
set listchars=tab:»\ ,trail:·,nbsp:+
set splitright
set splitbelow

set undofile
set undodir=~/.vim/undo/
set backupdir=~/.vim/backup/
set directory=~/.vim/swap/
set autoread
set updatetime=300

set completeopt=menuone,noinsert,noselect
set shortmess+=c

set diffopt+=vertical,algorithm:histogram,indent-heuristic

let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#whitespace#enabled = 1

let g:airline_theme = 'catppuccin_frappe'
let g:airline_powerline_fonts = 1

augroup prettier_format
  autocmd!
  autocmd BufWritePre *.js,*ts
        \ silent! %!prettier --stdin-filepath %
augroup END
