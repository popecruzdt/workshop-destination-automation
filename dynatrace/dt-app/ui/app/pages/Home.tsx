import React from "react";

import { useCurrentTheme } from "@dynatrace/strato-components/core";
import { Flex } from "@dynatrace/strato-components/layouts";
import {
  Heading,
  Paragraph,
  Strong,
} from "@dynatrace/strato-components/typography";
import { Card } from "../components/Card";

export const Home = () => {
  const theme = useCurrentTheme();
  return (
    <Flex flexDirection="column" alignItems="center" padding={32}>
      <img
        src="./assets/Dynatrace_Logo.svg"
        alt="Dynatrace Logo"
        width={150}
        height={150}
        style={{ paddingBottom: 32 }}
      ></img>

      <Heading>Destination Automation App</Heading>
      <Paragraph>
        Custom Dynatrace app workspace for the workshop environment at <Strong>hfn13693.apps.dynatrace.com</Strong>.
      </Paragraph>
      <Paragraph>
        Use this starter to build dashboards and workflows around the AI Travel Advisor, automation flows, and observability data.
      </Paragraph>
      <Paragraph>
        Start by editing <Strong>ui/app/pages/Home.tsx</Strong>, adding data views, or wiring in DQL-backed components.
      </Paragraph>

      <Flex gap={48} paddingTop={64} flexFlow="wrap">
        <Card
          href="/data"
          inAppLink
          imgSrc={
            theme === "light" ? "./assets/data.png" : "./assets/data_dark.png"
          }
          name="Explore data"
        />
        <Card
          href="https://dt-url.net/developers"
          imgSrc={
            theme === "light"
              ? "./assets/devportal.png"
              : "./assets/devportal_dark.png"
          }
          name="Developer docs"
        />
        <Card
          href="https://dt-url.net/devcommunity"
          imgSrc={
            theme === "light"
              ? "./assets/community.png"
              : "./assets/community_dark.png"
          }
          name="Community"
        />
      </Flex>
    </Flex>
  );
};
