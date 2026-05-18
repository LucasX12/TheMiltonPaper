import Foundation

// Sample articles shown when the RSS feed URL hasn't been configured yet.
enum MockData {
    static let articles: [Article] = [
        Article(
            id: "article-1",
            title: "Milton Academy Hosts Annual Science Fair with Record Participation",
            author: "Emily Chen",
            publishedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            category: "News",
            summary: "Over 120 students presented projects ranging from AI-powered soil sensors to biodegradable plastics this year, marking a record-breaking turnout for the school's beloved science competition.",
            bodyHTML: """
<p>This year's Milton Academy Science Fair drew record participation, with over 120 students presenting projects that spanned disciplines from artificial intelligence to environmental engineering.</p>
<p>Judges — including three MIT professors and alumni from local biotech firms — spent nearly six hours evaluating the submissions. "The quality this year is genuinely remarkable," said Dr. Sarah Okonkwo, a biology professor who served as head judge. "These students are tackling real problems."</p>
<h2>Top Winners</h2>
<p>First place in the Environmental Science category went to junior Maya Patel for her work on AI-powered soil sensors capable of detecting early signs of drought stress in crops. She will advance to the state competition in June.</p>
<p>The Engineering prize was awarded to sophomores Jake Torres and Priya Nair for a prototype biodegradable plastic alternative made from seaweed extract and cornstarch.</p>
<p>Full results are available on the school's science department website.</p>
""",
            articleURL: URL(string: "https://example.com/science-fair")!,
            thumbnailURL: nil
        ),
        Article(
            id: "article-2",
            title: "Opinion: We Need More Sleep, Not More Homework",
            author: "Marcus Williams",
            publishedDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            category: "Opinion",
            summary: "A call for the administration to reconsider late-night assignment loads in the wake of new research linking sleep deprivation to declining academic performance.",
            bodyHTML: """
<p>Last month, the American Academy of Sleep Medicine published findings showing that teenagers who sleep fewer than eight hours a night score, on average, one letter grade lower than their well-rested peers. As a Milton junior averaging six hours a night, those statistics hit close to home.</p>
<p>I'm not arguing that we abandon academic rigor. Milton's reputation is built on it, and I wouldn't trade my education here for anything. But there's a difference between rigorous and relentless.</p>
<p>When teachers in four different classes all assign major projects in the same two-week window — and that's not a hypothetical, that's last October — something has to give. And too often, what gives is sleep.</p>
<p>I'm asking the administration to consider a simple change: a coordinated assignment calendar that prevents the simultaneous pile-on of major deadlines across departments. Other schools have implemented similar systems with measurable results. Ours can too.</p>
<p>We came here to learn. Let us also sleep.</p>
""",
            articleURL: URL(string: "https://example.com/opinion-sleep")!,
            thumbnailURL: nil
        ),
        Article(
            id: "article-3",
            title: "Varsity Soccer Advances to State Semifinals After Comeback Victory",
            author: "Jordan Park",
            publishedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            category: "Sports",
            summary: "Down two goals at halftime, the Panthers rallied with three unanswered second-half strikes to defeat rival Westbrook 3–2 and punch their ticket to the state semifinals.",
            bodyHTML: """
<p>The Milton Panthers needed a miracle at halftime, and they got one — delivered by senior midfielder Aisha Okafor, whose hat trick powered a stunning 3–2 comeback victory over rival Westbrook Academy on Saturday.</p>
<p>Westbrook had dominated the first 45 minutes, converting two set pieces to go into the break with a commanding lead. Head coach Diana Ruiz said she told her team at halftime to simplify their game. "Stop trying to be perfect and just play football," she told them.</p>
<p>Whatever she said worked. Okafor scored just four minutes into the second half, then equalized with a long-range strike in the 67th minute that silenced the visiting crowd. Her winner came in the 88th, a clinical finish off a corner that sent the Milton sideline into bedlam.</p>
<p>"I've never felt anything like that," Okafor said after the game, still catching her breath. "We believed the whole time."</p>
<p>The Panthers face Northside Prep in the state semifinals on Saturday, November 14th at 2 PM.</p>
""",
            articleURL: URL(string: "https://example.com/soccer-semifinals")!,
            thumbnailURL: nil
        ),
        Article(
            id: "article-4",
            title: "Drama Department's 'Hamlet' Earns Standing Ovation on Opening Night",
            author: "Sofia Rodriguez",
            publishedDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            category: "Arts",
            summary: "The fall production of Shakespeare's Hamlet, directed by drama teacher Mr. Harrington, drew 400 audience members and earned a thunderous standing ovation for its modern reimagining.",
            bodyHTML: """
<p>There's a moment in Act III when Hamlet — played here by senior Daniel Abrams in a black hoodie and sneakers — looks directly into the audience and whispers "To be or not to be." Friday night, you could have heard a pin drop.</p>
<p>Milton's Drama Department opened its fall production of Hamlet to a packed auditorium of over 400 students, parents, and faculty. The show, directed by Mr. James Harrington, set the Danish tragedy in a modern high school, with Elsinore reimagined as a boarding academy not unlike Milton itself.</p>
<p>"The themes are timeless," said Mr. Harrington. "Grief, corruption, the pressure to perform — these aren't abstractions for our students. They live them."</p>
<p>Abrams was luminous in the title role, but the production's emotional anchor was sophomore Lily Cheng as Ophelia, whose descent into grief in Act IV left several audience members visibly moved. Junior Kwame Asante brought sharp wit to a reimagined Horatio who narrates events via smartphone video.</p>
<p>The show runs through Sunday. Tickets are $8 for students and $12 for adults, available at the main office.</p>
""",
            articleURL: URL(string: "https://example.com/hamlet-opening")!,
            thumbnailURL: nil
        ),
        Article(
            id: "article-5",
            title: "New Student Wellness Center Opens With Full-Time Counseling Staff",
            author: "Emily Chen",
            publishedDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            category: "News",
            summary: "The renovated wellness center, featuring four private counseling offices and a meditation room, opens this week as part of the school's expanded mental health initiative.",
            bodyHTML: """
<p>After nearly a year of construction, Milton Academy's new Student Wellness Center officially opened its doors Monday morning, offering students expanded access to mental health resources and a dedicated space for counseling and mindfulness.</p>
<p>The 2,400-square-foot facility — located in the renovated east wing of the Main Building — features four private counseling offices, a meditation and relaxation room, peer support group space, and a resource library.</p>
<p>Crucially, the center will be staffed full-time. The school has hired two additional licensed clinical social workers, bringing the total counseling staff to five. Head of Student Services Dr. Maria Fontaine said the expansion was driven by a surge in student demand for support services over the past three years.</p>
<p>"Mental health is academic health," Dr. Fontaine said at the ribbon-cutting ceremony. "We want students to know that asking for help is a strength, not a weakness."</p>
<p>The center is open Monday through Friday, 8 AM to 6 PM. Students can book appointments online through the student portal or walk in during open hours.</p>
""",
            articleURL: URL(string: "https://example.com/wellness-center")!,
            thumbnailURL: nil
        ),
        Article(
            id: "article-6",
            title: "Alumni Spotlight: Former Editor-in-Chief Now at the New York Times",
            author: "Marcus Williams",
            publishedDate: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
            category: "News",
            summary: "We caught up with class of 2018 alumna and former Milton Paper editor-in-chief Nadia Hassan, now a culture correspondent at the New York Times, on her path from student journalist to the Gray Lady.",
            bodyHTML: """
<p>Nadia Hassan '18 remembers exactly where she was when she got the call from the New York Times. "I was in a Starbucks in Brooklyn, and I just started ugly crying," she laughs. "The barista thought someone had died."</p>
<p>Hassan, who served as editor-in-chief of The Milton Paper during her senior year, is now a culture correspondent at the Times, covering film, television, and the intersection of art and politics. Her profile last spring of a first-generation filmmaker from Houston — told through the lens of a single short film — was widely shared and nominated for a feature writing award.</p>
<p>She credits The Milton Paper with giving her the foundation to do that work. "I learned how to report here. How to ask hard questions. How to care about getting it right," she says. "That doesn't sound glamorous, but it's everything."</p>
<p>Hassan will return to campus in February as part of the alumni speaker series. Details will be announced in a future issue.</p>
""",
            articleURL: URL(string: "https://example.com/alumni-spotlight")!,
            thumbnailURL: nil
        )
    ]
}
