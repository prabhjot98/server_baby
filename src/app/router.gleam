import wisp.{type Request, type Response}
import gleam/string_builder
import gleam/result
import gleam/string
import gleam/json
import gleam/http.{Post}
import gleam/dynamic.{type Dynamic}
import app/web

pub type Color {
  Red
  Orange
  Yellow
  Green
  Blue
  Purple
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
    "0range" -> Ok(Orange)
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

/// The HTTP request handler- your application!
/// 
pub fn handle_request(req: Request) -> Response {
  // Apply the middleware stack for this request/response.
  use _req <- web.middleware(req)

  // Later we'll use templates, but for now a string will do.
  let body = string_builder.from_string("<h1>Weelcoomee</h1>")

  // Return a 200 OK response with the body and a HTML content type.
  wisp.html_response(body, 200)
}

pub fn handle_json(req: Request) -> Response {
  // Apply the middleware stack for this request/response.
  use _req <- web.middleware(req)
  use <- wisp.require_method(req, Post)

  use json <- wisp.require_json(req)

  let result = {
    use fruit <- result.try(decode_fruit(json))

    // we have a fruit here
    let resp = json.object([#("name", json.string(fruit.name))])

    Ok(json.to_string_builder(resp))
  }

  case result {
    Ok(alright) -> wisp.json_response(alright, 200)
    Error(_) -> wisp.unprocessable_entity()
  }
}
