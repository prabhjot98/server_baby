import gleam/erlang/process
import mist
import wisp
import app/router
import sqlight

pub fn main() {
  // This sets the logger to print INFO level logs, and other sensible defaults
  // for a web application.
  wisp.configure_logger()

  // do sql setup things
  use connection <- sqlight.with_connection("sqlite:deeb.db")

  let sql = "CREATE TABLE fruits ( name TEXT, sweetness INT, color TEXT );"
  let _ = sqlight.exec(sql, connection)

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  // Start the Mist web server.
  let assert Ok(_) =
    wisp.mist_handler(router.handle_request(connection, _), secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}
