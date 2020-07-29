use Mojolicious::Lite -signatures;
# Download log.sqlite3: https://github.com/preaction/Yancy/tree/master/eg/cookbook/log.sqlite3
plugin Yancy => { backend => 'sqlite:log.sqlite3', read_schema => 1 };
under sub( $c ) {
    my $levels = $c->every_param( 'log_level' );
    if ( @$levels ) {
        # Include only log levels requested
        $c->stash( filter => { log_level => $levels } );
    }
    return 1;
};
get '/' => {
    controller => 'Yancy',
    action => 'list',
    schema => 'log',
    template => 'log',
};
app->start;
__DATA__
@@ log.html.ep
%= form_for current_route, begin
    % for my $log_level ( qw( debug info warn error ) ) {
        %= label_for "log_level_$log_level", begin
            %= ucfirst $log_level
            %= check_box log_level => $log_level
        % end
    % }
    %= submit_button 'Filter'
% end
%= include 'yancy/table'
