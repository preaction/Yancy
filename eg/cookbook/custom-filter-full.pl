use Mojo::Base -signatures;
package MyApp::Controller::Log {
    use Mojo::Base 'Yancy::Controller::Yancy', -signatures;
    sub list_log( $self ) {
        my $levels = $self->every_param( 'log_level' );
        if ( @$levels ) {
            # Include only log levels requested
            $self->stash( filter => { log_level => $levels } );
        }
        return $self->SUPER::list;
    }
}

package MyApp {
    use Mojo::Base 'Mojolicious', -signatures;
    sub startup( $self ) {
        push @{ $self->renderer->classes }, 'main';
        push @{ $self->routes->namespaces }, 'MyApp::Controller';

        # Download log.db: http://github.com/preaction/Yancy/tree/master/eg/cookbook/log.sqlite3
        $self->plugin( Yancy => {
            backend => 'sqlite:log.sqlite3',
            read_schema => 1,
        } );

        $self->routes->get( '/' )->to(
            controller => 'Log',
            action => 'list_log',
            schema => 'log',
            template => 'log',
        );
    }
}

Mojolicious::Commands->new->start_app( 'MyApp' );
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
