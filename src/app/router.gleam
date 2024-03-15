import wisp.{type Request, type Response}
import gleam/result
import gleam/string
import gleam/io
import gleam/int
import gleam/json
import gleam/http.{Get, Post}
import gleam/dynamic.{type Dynamic}
import app/web
import sqlight

pub type Color {
  Red
  Orange
  Yellow
  Green
  Blue
  Purple
}

fn to_string(color: Color) -> String {
  case color {
    Red -> "red"
    Orange -> "orange"
    Yellow -> "yellow"
    Green -> "green"
    Blue -> "blue"
    Purple -> "purple"
  }
}

fn fruple_to_json(fruple: #(String, Int, Color)) {
  json.object([
    #("name", json.string(fruple.0)),
    #("sweetness", json.int(fruple.1)),
    #(
      "color",
      json.string(
        fruple.2
        |> to_string,
      ),
    ),
  ])
}

pub type Fruit {
  Fruit(name: String, sweetness: Int, color: Color)
}

fn decode_color(str: Dynamic) -> Result(Color, dynamic.DecodeErrors) {
  use dyn_str <- result.try(dynamic.string(from: str))
  let lowercase_dyn_str =
    dyn_str
    |> string.lowercase
    |> string.trim

  case lowercase_dyn_str {
    "red" -> Ok(Red)
    "orange" -> Ok(Orange)
    "yellow" -> Ok(Yellow)
    "green" -> Ok(Green)
    "blue" -> Ok(Blue)
    "purple" -> Ok(Purple)
    _ -> Error([dynamic.DecodeError("A real color", dyn_str, [])])
  }
}

fn decode_fruit(data: Dynamic) -> Result(Fruit, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode3(
      Fruit,
      dynamic.field("name", dynamic.string),
      dynamic.field("sweetness", dynamic.int),
      dynamic.field("color", decode_color),
    )

  decoder(data)
}

pub fn handle_request(connection: sqlight.Connection, req: Request) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["fruits"] -> handle_fruits(connection, req)
    _ -> wisp.not_found()
  }
}

fn handle_fruits(connection: sqlight.Connection, req: Request) -> Response {
  case req.method {
    Post -> new_fruit(connection, req)
    Get -> all_fruits(connection, req)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}

fn all_fruits(connection: sqlight.Connection, req: Request) -> Response {
  // Apply the middleware stack for this request/response.
  use _req <- web.middleware(req)
  use <- wisp.require_method(req, Get)

  // Later we'll use templates, but for now a string will do.
  let result = {
    let sql = "SELECT * FROM fruits"
    use fruits <- result.try(sqlight.query(
      sql,
      on: connection,
      with: [],
      expecting: dynamic.tuple3(dynamic.string, dynamic.int, decode_color),
    ))

    let fruit_json = json.array(fruits, fruple_to_json)
    Ok(json.to_string_builder(fruit_json))
  }

  case result {
    Ok(alright) -> wisp.json_response(alright, 200)
    Error(e) -> {
      io.debug(e)
      wisp.unprocessable_entity()
    }
  }
}

fn new_fruit(connection: sqlight.Connection, req: Request) -> Response {
  // Apply the middleware stack for this request/response.
  use _req <- web.middleware(req)
  use <- wisp.require_method(req, Post)

  use json <- wisp.require_json(req)

  let result = {
    use fruit <- result.try(decode_fruit(json))

    // we have a fruit here
    // dunk it
    let sql = "INSERT INTO fruits ( name, sweetness, color ) VALUES   
        ( '" <> fruit.name <> "', '" <> fruit.sweetness
      |> int.to_string <> "', '" <> fruit.color
      |> to_string <> "' );"
    let assert Ok(Nil) = sqlight.exec(sql, connection)

    let resp = json.object([#("name", json.string(fruit.name))])
    Ok(json.to_string_builder(resp))
  }

  case result {
    Ok(alright) -> wisp.json_response(alright, 200)
    Error(_) -> wisp.unprocessable_entity()
  }
}
