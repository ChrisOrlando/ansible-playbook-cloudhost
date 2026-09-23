require 'serverspec'

set :backend, :exec

# InterWorx rotates MariaDB's root credentials during its install and uses a
# provisioned `iworx` superuser instead, recording the connection in iworx.ini:
#
#   rootdsn="mysqli://iworx:PASSWORD@unix(/var/lib/mysql/mysql.sock)/mysql"
#
# so `mysql -u root` is refused on a provisioned host. Reading rootdsn back is
# the documented way to get a root-equivalent shell:
# https://appendix.interworx.com/current/troubleshooting/mysql/connection-issue-mariadb.html
#
# Credentials are split on the *last* "@unix(" so a password containing an @
# still parses. stderr is folded into stdout so a failing expectation shows the
# client's error instead of an empty string. sql must not contain a single quote.
def iworx_mysql(sql)
  [
    'ini=/usr/local/interworx/iworx.ini',
    '[ -f "$ini" ] || ini=/home/interworx/iworx.ini',
    %q(dsn=$(grep -m1 '^rootdsn' "$ini" | cut -d= -f2- | tr -d '" ')),
    '[ -n "$dsn" ] || { echo "no rootdsn in $ini"; exit 1; }',
    'raw=${dsn#mysqli://}',
    'cred=${raw%@unix(*}',
    'sock=${raw##*@unix(}',
    'sock=${sock%%)*}',
    "mysql -N -B -u\"${cred%%:*}\" -p\"${cred#*:}\" -S\"$sock\" -e '#{sql}' 2>&1"
  ].join('; ')
end
