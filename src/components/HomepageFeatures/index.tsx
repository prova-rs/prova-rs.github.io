import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  icon: string;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'A Real Language for Tests',
    icon: '⚙️',
    description: (
      <>
        Loops, conditionals, computed values, reusable helpers — Lua, not YAML.
        The moment declarative testers hit a wall, Prova is just getting
        started.
      </>
    ),
  },
  {
    title: 'Fixtures Done Right',
    icon: '🧩',
    description: (
      <>
        pytest-grade fixtures with test, flow, file, and suite scopes,
        dependency injection, caching, and guaranteed LIFO teardown — setup and
        cleanup live together.
      </>
    ),
  },
  {
    title: 'One Static Binary',
    icon: '🚀',
    description: (
      <>
        Written in Rust, installed as a single executable. No interpreter, no
        virtualenv, no node_modules — the same binary on laptops and CI.
      </>
    ),
  },
  {
    title: 'Batteries for Black-Box Testing',
    icon: '🔋',
    description: (
      <>
        shell, HTTP, gRPC, GraphQL, Docker, Postgres/MySQL, Redis, Kafka,
        Pulsar, S3 — first-party modules to boot a system and poke it.
      </>
    ),
  },
  {
    title: 'Parallel Without Surprises',
    icon: '🧵',
    description: (
      <>
        Independence is the default; ordering is explicit (<code>flow</code>),
        dependencies form a DAG, and shared resources are declared.{' '}
        <code>--jobs</code> changes speed, never meaning.
      </>
    ),
  },
  {
    title: 'Test Your Generators',
    icon: '🏗️',
    description: (
      <>
        Sibling to <a href="https://archetect.github.io">Archetect</a>: render
        an archetype in-process, build it, boot it, and prove the generated
        service actually works — not just that it compiles.
      </>
    ),
  },
];

function Feature({title, icon, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4', styles.feature)}>
      <div className="text--center">
        <div className={styles.featureIcon}>{icon}</div>
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.slice(0, 3).map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
        <div className="row">
          {FeatureList.slice(3, 6).map((props, idx) => (
            <Feature key={idx + 3} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
