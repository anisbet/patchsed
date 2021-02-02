# Add line to source a file after she-bang. Change /s/sirsi to ${HOME}.
1a\. ~/.bashrc
# The next is not good for Makefiles since it references local $HOME not sirsi's $HOME so suggest '~'
# Change /s/sirsi in comments to /software/EDPL in comments, and in non-comments to ${HOME}.
s:/s/sirsi:${HOME}:g