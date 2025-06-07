local parse = require("present")._parse_slides

local eq = assert.are.same

describe("present.parse_slides", function()
  it("should parse an empty file", function()
    eq({
      slides = {
        {
          title = "",
          body = {},
        },
      },
    }, parse {})
  end)

  it("should parse a file with 1 slide", function()
    eq(
      {
        slides = {
          {
            title = "# First Slide",
            body = { "First slide content" },
          },
        },
      },
      parse {
        "# First Slide",
        "First slide content",
      }
    )
  end)

  it("should parse a file with multiple slides", function()
    eq(
      {
        slides = {
          {
            title = "# First Slide",
            body = { "First slide content" },
          },
          {
            title = "# Second Slide",
            body = { "Second slide content" },
          },
        },
      },
      parse {
        "# First Slide",
        "First slide content",
        "# Second Slide",
        "Second slide content",
      }
    )
  end)
end)
