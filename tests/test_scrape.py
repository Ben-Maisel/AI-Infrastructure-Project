from agent.scrape import clean_text


def test_clean_text_strips_noise_and_keeps_content():
    html = """
    <html><body>
    <nav>Skip nav</nav>
    <main>
      <script>var x = 1;</script>
      <style>.a{color:red}</style>
      <h1>Pods</h1>
      <p>A Pod is the smallest deployable unit.</p>
      <footer>Edit this page</footer>
    </main>
    </body></html>
    """

    text = clean_text(html)

    assert "Skip nav" not in text
    assert "var x = 1" not in text
    assert "color:red" not in text
    assert "Edit this page" not in text
    assert "Pods" in text
    assert "smallest deployable unit" in text


def test_clean_text_falls_back_to_body_without_main():
    html = "<html><body><p>Just body content.</p></body></html>"

    text = clean_text(html)

    assert "Just body content." in text
