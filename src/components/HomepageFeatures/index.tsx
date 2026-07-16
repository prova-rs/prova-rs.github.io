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
    title: 'Proof-Driven Development',
    icon: '🎯',
    description: (
      <>
        Humans define an executable, black-box proof of what the system must
        do; implementers — increasingly agents — drive it green; CI holds the
        bar after every context is gone. Render, build, boot, probe.
      </>
    ),
  },
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
    title: 'Plugins, Zero Native Code',
    icon: '🔌',
    description: (
      <>
        Official plugins for Postgres, MySQL, Redis, Kafka, Pulsar, RabbitMQ,
        and S3 — pure Lua over docker-exec, authored through{' '}
        <code>prova.containerized</code>. Declare in <code>[plugins]</code>,{' '}
        <code>require</code>, done.
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
