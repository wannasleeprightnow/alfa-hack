import '@fontsource-variable/inter-tight/wght.css'
import '@fontsource/ibm-plex-mono/latin-400.css'

function Digits({ className }: { className: string }) {
  return (
    <span className={className} aria-hidden="true">
      <span className="digit digit-four">4</span>
      <span className="digit digit-one">1</span>
      <span className="digit digit-eight">8</span>
    </span>
  )
}
export function App() {
  return (
    <main id="top" className="hero" aria-labelledby="hero-title">
      <header className="header">
        <a className="wordmark" href="#top" aria-label="418 home">
          418<sup>®</sup>
        </a>
        <p className="mono header-caption">
          INDEPENDENT HACKATHON TEAM <span>/ 2026</span>
        </p>
      </header>
      <div className="hero-art">
        <h1 id="hero-title" className="hero-title" aria-label="418 is going to rob a bank.">
          <span className="number-mask">
            <span className="number-layer">
              <Digits className="number-echo" />
              <Digits className="number-front" />
            </span>
          </span>
          <span className="slogan">
            <span aria-hidden="true">
              IS GOING TO
              <br />
              <span className="slogan-line">
                <strong>ROB</strong> A BANK.
              </span>
            </span>
            <span className="slogan-star" aria-hidden="true">
              ↗
            </span>
          </span>
        </h1>
      </div>
      <div className="hero-bottom mono">
        <p className="tagline">
          <span className="red-square" aria-hidden="true" />
          NO GUNS. JUST CODE.
        </p>
      </div>
    </main>
  )
}
