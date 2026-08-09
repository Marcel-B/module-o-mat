defmodule ModuleOMat.Inventory.YoutubeTest do
  use ExUnit.Case, async: true

  alias ModuleOMat.Inventory.Youtube

  describe "video_id/1" do
    test "erkennt watch-, short- und youtu.be-URLs" do
      assert Youtube.video_id("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ"
      assert Youtube.video_id("https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ"
      assert Youtube.video_id("https://www.youtube.com/embed/dQw4w9WgXcQ") == "dQw4w9WgXcQ"
      assert Youtube.video_id("https://www.youtube.com/shorts/dQw4w9WgXcQ") == "dQw4w9WgXcQ"
    end

    test "liefert nil bei ungueltigen Werten" do
      assert Youtube.video_id("https://example.com/watch?v=dQw4w9WgXcQ") == nil
      assert Youtube.video_id("not-a-video") == nil
      assert Youtube.video_id("dQw4w9WgXcQ") == nil
      assert Youtube.video_id(nil) == nil
    end
  end

  describe "watch_url/1 und embed_url/1" do
    test "baut kanonische URLs" do
      assert Youtube.watch_url("https://youtu.be/dQw4w9WgXcQ") ==
               "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

      assert Youtube.embed_url("https://youtu.be/dQw4w9WgXcQ") ==
               "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"

      assert Youtube.embed_url("https://youtu.be/dQw4w9WgXcQ", autoplay: true, mute: true) ==
               "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1"
    end
  end
end
