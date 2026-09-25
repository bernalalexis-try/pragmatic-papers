import type { Article, Page, Topic, Volume } from "@/payload-types"
import { DEFAULT_DESCRIPTION } from "@/utilities/mergeOpenGraph"
import { describe, expect, it } from "vitest"
import { generateDescription } from "../index"

type Args = Parameters<typeof generateDescription>[0]
type Doc = Volume | Article | Page | Topic

const describeDoc = (doc: Partial<Doc>) => generateDescription({ doc } as Args)

describe("generateDescription", () => {
  it.each([
    ["an article", { title: "On Pragmatism", slug: "on-pragmatism" }],
    ["a topic", { name: "Economics", slug: "economics" }],
    ["a volume", { volumeNumber: 3, slug: "volume-3" }],
    ["an empty doc", {}],
  ])("offers the site default description for %s", async (_, doc) => {
    expect(await describeDoc(doc as Partial<Doc>)).toBe(DEFAULT_DESCRIPTION)
  })
})
