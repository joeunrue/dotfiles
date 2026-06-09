let mapleader = "\\"

set backspace=2
set nobackup
set nowritebackup
set noswapfile
set history=50
set ruler
set showcmd
set incsearch
set laststatus=2
set autowrite
set hlsearch
set nojoinspaces
set viminfo="20,<1000,s1000"
set lazyredraw

" Relative line numbers
set relativenumber
set number
set numberwidth=5

" Softtabs, 2 spaces
set tabstop=2
set shiftwidth=2
set shiftround
set expandtab

set list listchars=tab:»·,trail:·,nbsp:·
set textwidth=80
set colorcolumn=""
set splitbelow
set splitright
set diffopt+=vertical
set complete+=kspell
set spellfile=$HOME/.vim-spell-en.utf-8.add
set wildmode=list:longest,list:full
set wildignore+=*/log/**,*/vendor/**,*/public/**

" Window sizing
set winwidth=84
set winheight=5
set winminheight=5
set winheight=999

if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif

source ~/.config/nvim/bundles.vim

if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &rtp) ==# ''
  runtime! macros/matchit.vim
endif

filetype plugin indent on

" Colors
set t_Co=256
set background=dark
colorscheme railscasts

if &term =~ '256color'
  set t_ut=
endif

augroup vimrcEx
  autocmd!
  autocmd BufReadPost *
    \ if &ft != 'gitcommit' && line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif
  autocmd BufRead,BufNewFile Appraisals set filetype=ruby
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  autocmd FileType markdown setlocal spell
  autocmd BufRead,BufNewFile *.md setlocal textwidth=80
  autocmd FileType gitcommit setlocal textwidth=72
  autocmd FileType gitcommit setlocal spell
  autocmd FileType css,scss,sass setlocal iskeyword+=-
augroup END

" Use ag over grep
if executable('ag')
  set grepprg=ag\ --nogroup\ --nocolor
  let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
  let g:ctrlp_use_caching = 0
endif

let g:Tlist_Ctags_Cmd="ctags --exclude='*.js'"
let g:syntastic_check_on_open=1
let g:syntastic_html_tidy_ignore_errors=[" proprietary attribute \"ng-"]
let g:syntastic_eruby_ruby_quiet_messages =
    \ {"regex": "possibly useless use of a variable in void context"}

let g:vitality_fix_cursor = 1
let g:vitality_fix_focus = 0
let g:vitality_always_assume_iterm = 1

" Tab completion
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
    else
        return "\<c-p>"
    endif
endfunction
inoremap <Tab> <c-r>=InsertTabWrapper()<cr>
inoremap <S-Tab> <c-n>

" Escape with jk/kj
inoremap jk <ESC>
inoremap kj <ESC>

" Window movement
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l

" Switch between last two files
nnoremap <leader><leader> <c-^>

" Fancy path expansion
cnoremap %% <C-R>=expand('%:h').'/'<cr>
map <leader>e :edit %%
map <leader>v :view %%

" Whitespace cleanup
map <leader>st mm:%s/\t/  /g<CR>`m
map <leader>sw mm:%s/ \+$//g<CR>`m
map <leader>sh mm:%s/:\([a-z_]\+\) \?=> \?/\1: /g<CR>`m
map <leader>so :so$MYVIMRC<CR>
map <leader>se :e ~/.config/nvim/init.vim<CR>

" Rails navigation
map <leader>gr :topleft :split config/routes.rb<cr>
map <leader>gg :topleft 100 :split Gemfile<cr>

" vim-rspec
nnoremap <Leader>t :call RunCurrentSpecFile()<CR>
nnoremap <Leader>s :call RunNearestSpec()<CR>
nnoremap <Leader>l :call RunLastSpec()<CR>
nnoremap <Leader>r :RunInInteractiveShell<space>

map <Leader>ct :!ctags -R .<CR>

" FZF
map <C-p> :FZF<cr>
map <leader>gv :FZF app/views/<cr>
map <leader>gc :FZF app/controllers/<cr>
map <leader>gm :FZF app/models/<cr>
map <leader>gh :FZF app/helpers/<cr>
map <leader>gl :FZF lib/<cr>
map <leader>gs :FZF spec/<cr>

" Enforce arrow key avoidance
nnoremap <Left> :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up> :echoe "Use k"<CR>
nnoremap <Down> :echoe "Use j"<CR>

let g:html_indent_tags = 'li\|p'
