require "date"
require "resyma/nise/date"
require "resyma/nise/toml"
require "resyma/nise/rubymoji"

RSpec.describe LangDate do
  it "reads literal 'today'" do
    expect(date { today }).to eq Date.today
  end

  it "reads literal in form Y/M/D" do
    expect(date { 2020/1/1 }).to eq Date.new(2020, 1, 1)
  end

  it "reads literal in form of offset" do
    expect(date { +1.day }).to eq Date.today.next_day
    expect(date { -5.day }).to eq Date.today.next_day(-5)
    expect(date { +3.month }).to eq Date.today.next_month(3)
    expect(date { -12.month }).to eq Date.today.next_month(-12)
    expect(date { -4.year }).to eq Date.today.next_year(-4)
    expect(date { +10.year }).to eq Date.today.next_year(10)
  end

  it "reads literal tomorrow/yesterday" do
    expect(date { tomorrow }).to eq Date.today.next_day
    expect(date { yesterday }).to eq Date.today.next_day(-1)
  end
end

RSpec.describe LangTimeline do
  it "can build timeline with single item" do
    timeline = LangTimeline.load do
      [today] - "Zzz..."
    end
    expect(timeline).to eq [
      [Date.today, "Zzz..."]
    ]
  end

  it "can build timeline with multiple items" do
    timeline = LangTimeline.load do
      [2020/8/15] - "First day of class"
      [2020/10/9] - "Test #1"
      [yesterday] - "Research paper due"
      [today]     - "Zzz..."
      [+7.day]    - "Test #2"
      [+2.month]  - "Final project due"
    end
    expect(timeline).to eq [
      [Date.new(2020, 8, 15), "First day of class"],
      [Date.new(2020, 10, 9), "Test #1"],
      [Date.today.next_day(-1), "Research paper due"],
      [Date.today, "Zzz..."],
      [Date.today.next_day(7), "Test #2"],
      [Date.today.next_month(2), "Final project due"]
    ]
  end
end

RSpec.describe LangTOML do
  it "builds simple TOML" do
    toml = LangTOML.load do

      # This is a nise-TOML document

      title = "TOML Example"

      [owner]
      name = "Tom Preston-Werner"

      [database]
      enabled = true
      ports = [ 8000, 8001, 8002 ]
      data = [ ["delta", "phi"], [3.14] ]
      temp_targets = { cpu: 79.5, case: 72.0 }

      [servers]

      [servers.alpha]
      ip = "10.0.0.1"
      role = "frontend"

      [servers.beta]
      ip = "10.0.0.2"
      role = "backend"
    end
    expect(toml).to eq({
      title: "TOML Example",
      owner: {
        name: "Tom Preston-Werner"
      },
      database: {
        enabled: true,
        ports: [8000, 8001, 8002],
        data: [["delta", "phi"], [3.14]],
        temp_targets: { cpu: 79.5, case: 72.0 }
      },
      servers: {
        alpha: {
          ip: "10.0.0.1",
          role: "frontend"
        },
        beta: {
          ip: "10.0.0.2",
          role: "backend"
        }
      }
    })
  end
end

RSpec.describe LangRubymoji do
  it "works" do
    expect(rubymoji { o^o }).to eq "🙃"
    expect(rubymoji { O.O ?? }).to eq "🤔"
    expect(rubymoji { Zzz.. (x.x) }).to eq "😴"
  end
end