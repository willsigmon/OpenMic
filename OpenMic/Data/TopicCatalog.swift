import SwiftUI

enum TopicCatalog {
    static let categories: [TopicCategory] = [
        news,
        entertainment,
        learning,
        philosophy,
        gamesTrivia,
        creativeWriting,
        career,
        health,
        technology,
        travel,
        food,
        science,
        history,
        music,
        sports
    ]

    // MARK: - News & Current Events

    private static let news = TopicCategory(
        id: "news",
        name: "News & Current Events",
        icon: "newspaper.fill",
        color: .red,
        subcategories: [
            TopicSubcategory(
                id: "world-news",
                name: "World News",
                description: "Catch up on what's happening globally",
                prompts: [
                    TopicPrompt(id: "wn1", text: "What are the most important things happening in the world right now?", label: "World update"),
                    TopicPrompt(id: "wn2", text: "Can you explain the current situation in global politics?", label: "Global politics"),
                    TopicPrompt(id: "wn3", text: "What are the biggest humanitarian issues right now?", label: "Humanitarian issues"),
                    TopicPrompt(id: "wn4", text: "Tell me about recent international trade developments", label: "Trade news"),
                    TopicPrompt(id: "wn5", text: "What's happening with climate change policy worldwide?", label: "Climate policy")
                ]
            ),
            TopicSubcategory(
                id: "tech-news",
                name: "Tech News",
                description: "Latest in technology and innovation",
                prompts: [
                    TopicPrompt(id: "tn1", text: "What are the biggest tech stories this week?", label: "Tech roundup"),
                    TopicPrompt(id: "tn2", text: "Tell me about the latest developments in artificial intelligence", label: "AI updates"),
                    TopicPrompt(id: "tn3", text: "What new gadgets or devices have been announced recently?", label: "New gadgets"),
                    TopicPrompt(id: "tn4", text: "How is the electric vehicle market evolving?", label: "EV market"),
                    TopicPrompt(id: "tn5", text: "What's new in space exploration?", label: "Space news")
                ]
            ),
            TopicSubcategory(
                id: "business-finance",
                name: "Business & Finance",
                description: "Markets, economy, and business trends",
                prompts: [
                    TopicPrompt(id: "bf1", text: "How are the stock markets performing lately?", label: "Market update"),
                    TopicPrompt(id: "bf2", text: "What are the current trends in the economy?", label: "Economy trends"),
                    TopicPrompt(id: "bf3", text: "Tell me about any major business mergers or acquisitions", label: "M&A news"),
                    TopicPrompt(id: "bf4", text: "What industries are growing the fastest right now?", label: "Growth sectors"),
                    TopicPrompt(id: "bf5", text: "How is inflation affecting everyday consumers?", label: "Inflation impact")
                ]
            )
        ]
    )

    // MARK: - Entertainment

    private static let entertainment = TopicCategory(
        id: "entertainment",
        name: "Entertainment",
        icon: "film.fill",
        color: .purple,
        subcategories: [
            TopicSubcategory(
                id: "movies-tv",
                name: "Movies & TV",
                description: "What to watch and what's trending",
                prompts: [
                    TopicPrompt(id: "mt1", text: "What are the best movies released this year?", label: "Best movies"),
                    TopicPrompt(id: "mt2", text: "Recommend a TV show for someone who likes mystery thrillers", label: "Show recs"),
                    TopicPrompt(id: "mt3", text: "What upcoming movies are you most excited about?", label: "Upcoming films"),
                    TopicPrompt(id: "mt4", text: "Tell me about the most talked-about documentaries right now", label: "Documentaries"),
                    TopicPrompt(id: "mt5", text: "What classic movies should everyone watch at least once?", label: "Must-see classics"),
                    TopicPrompt(id: "mt6", text: "Compare the Marvel and DC cinematic universes", label: "Marvel vs DC")
                ]
            ),
            TopicSubcategory(
                id: "books-podcasts",
                name: "Books & Podcasts",
                description: "Reading and listening recommendations",
                prompts: [
                    TopicPrompt(id: "bp1", text: "What are the best books to read this year?", label: "Book picks"),
                    TopicPrompt(id: "bp2", text: "Recommend a podcast for my daily commute", label: "Podcast recs"),
                    TopicPrompt(id: "bp3", text: "What's the most thought-provoking book you know about?", label: "Deep reads"),
                    TopicPrompt(id: "bp4", text: "Tell me about popular true crime podcasts", label: "True crime pods"),
                    TopicPrompt(id: "bp5", text: "What are some great audiobooks for a road trip?", label: "Road trip books")
                ]
            ),
            TopicSubcategory(
                id: "gaming",
                name: "Gaming",
                description: "Video games and gaming culture",
                prompts: [
                    TopicPrompt(id: "gm1", text: "What are the best video games released this year?", label: "Top games"),
                    TopicPrompt(id: "gm2", text: "Recommend a relaxing game I can play to unwind", label: "Chill games"),
                    TopicPrompt(id: "gm3", text: "What's happening in the esports world?", label: "Esports update"),
                    TopicPrompt(id: "gm4", text: "Tell me about upcoming game releases I should look forward to", label: "Upcoming games"),
                    TopicPrompt(id: "gm5", text: "What are the most iconic video games of all time?", label: "All-time greats")
                ]
            )
        ]
    )

    // MARK: - Learning & Education

    private static let learning = TopicCategory(
        id: "learning",
        name: "Learning & Education",
        icon: "graduationcap.fill",
        color: .blue,
        subcategories: [
            TopicSubcategory(
                id: "explain-concepts",
                name: "Explain Like I'm Five",
                description: "Complex topics made simple",
                prompts: [
                    TopicPrompt(id: "eli1", text: "Explain quantum physics in simple terms", label: "Quantum physics"),
                    TopicPrompt(id: "eli2", text: "How does the stock market actually work?", label: "Stock market"),
                    TopicPrompt(id: "eli3", text: "Explain blockchain technology simply", label: "Blockchain"),
                    TopicPrompt(id: "eli4", text: "How does the internet actually send data across the world?", label: "How internet works"),
                    TopicPrompt(id: "eli5", text: "What is general relativity and why does it matter?", label: "Relativity"),
                    TopicPrompt(id: "eli6", text: "How do vaccines work in our bodies?", label: "Vaccines")
                ]
            ),
            TopicSubcategory(
                id: "languages",
                name: "Language Learning",
                description: "Practice and learn new languages",
                prompts: [
                    TopicPrompt(id: "ll1", text: "Teach me 10 useful phrases in Spanish for traveling", label: "Spanish phrases"),
                    TopicPrompt(id: "ll2", text: "What's the most efficient way to learn a new language?", label: "Learning tips"),
                    TopicPrompt(id: "ll3", text: "Help me practice conversational French", label: "French practice"),
                    TopicPrompt(id: "ll4", text: "What are the hardest languages for English speakers to learn?", label: "Hardest languages"),
                    TopicPrompt(id: "ll5", text: "Teach me some common Japanese greetings and customs", label: "Japanese basics")
                ]
            ),
            TopicSubcategory(
                id: "skills",
                name: "Practical Skills",
                description: "Learn useful real-world skills",
                prompts: [
                    TopicPrompt(id: "sk1", text: "What are the basics of personal finance everyone should know?", label: "Finance basics"),
                    TopicPrompt(id: "sk2", text: "Teach me the fundamentals of negotiation", label: "Negotiation 101"),
                    TopicPrompt(id: "sk3", text: "How can I improve my public speaking skills?", label: "Public speaking"),
                    TopicPrompt(id: "sk4", text: "What are essential first aid skills everyone should know?", label: "First aid"),
                    TopicPrompt(id: "sk5", text: "How do I start learning to code?", label: "Learn to code")
                ]
            )
        ]
    )

    // MARK: - Philosophy & Deep Thinking

    private static let philosophy = TopicCategory(
        id: "philosophy",
        name: "Philosophy & Ideas",
        icon: "brain.fill",
        color: .indigo,
        subcategories: [
            TopicSubcategory(
                id: "big-questions",
                name: "Big Questions",
                description: "Life's deepest questions explored",
                prompts: [
                    TopicPrompt(id: "bq1", text: "What is the meaning of life according to different philosophies?", label: "Meaning of life"),
                    TopicPrompt(id: "bq2", text: "Do we have free will, or is everything predetermined?", label: "Free will"),
                    TopicPrompt(id: "bq3", text: "What makes something morally right or wrong?", label: "Morality"),
                    TopicPrompt(id: "bq4", text: "Is artificial intelligence truly capable of thinking?", label: "AI consciousness"),
                    TopicPrompt(id: "bq5", text: "What would a perfect society look like?", label: "Utopia"),
                    TopicPrompt(id: "bq6", text: "Does the universe have a purpose?", label: "Cosmic purpose")
                ]
            ),
            TopicSubcategory(
                id: "thought-experiments",
                name: "Thought Experiments",
                description: "Mind-bending hypotheticals",
                prompts: [
                    TopicPrompt(id: "te1", text: "Walk me through the trolley problem and its variations", label: "Trolley problem"),
                    TopicPrompt(id: "te2", text: "If you could live forever, would you want to? Why or why not?", label: "Immortality"),
                    TopicPrompt(id: "te3", text: "What if we discovered we're living in a simulation?", label: "Simulation theory"),
                    TopicPrompt(id: "te4", text: "If you could go back in time and change one historical event, what would it be?", label: "Time travel"),
                    TopicPrompt(id: "te5", text: "What would happen if everyone on Earth could read minds?", label: "Mind reading")
                ]
            ),
            TopicSubcategory(
                id: "ethics",
                name: "Modern Ethics",
                description: "Ethical dilemmas of our time",
                prompts: [
                    TopicPrompt(id: "et1", text: "What are the ethical implications of genetic engineering?", label: "Gene editing ethics"),
                    TopicPrompt(id: "et2", text: "Should social media companies be responsible for content on their platforms?", label: "Social media ethics"),
                    TopicPrompt(id: "et3", text: "Is it ethical to use AI to make important decisions about people's lives?", label: "AI ethics"),
                    TopicPrompt(id: "et4", text: "What are the ethics of wealth inequality?", label: "Wealth ethics"),
                    TopicPrompt(id: "et5", text: "Should there be limits on scientific research?", label: "Science limits")
                ]
            )
        ]
    )

    // MARK: - Games & Trivia

    private static let gamesTrivia = TopicCategory(
        id: "games",
        name: "Games & Trivia",
        icon: "dice.fill",
        color: .orange,
        subcategories: [
            TopicSubcategory(
                id: "trivia",
                name: "Trivia Challenge",
                description: "Test your knowledge",
                prompts: [
                    TopicPrompt(id: "tr1", text: "Give me 10 fun trivia questions to test my knowledge", label: "Trivia quiz"),
                    TopicPrompt(id: "tr2", text: "Let's play a geography trivia game", label: "Geography trivia"),
                    TopicPrompt(id: "tr3", text: "Quiz me on world history", label: "History quiz"),
                    TopicPrompt(id: "tr4", text: "Test my knowledge about science and nature", label: "Science trivia"),
                    TopicPrompt(id: "tr5", text: "Let's play a pop culture trivia game", label: "Pop culture quiz")
                ]
            ),
            TopicSubcategory(
                id: "word-games",
                name: "Word Games",
                description: "Fun with language and wordplay",
                prompts: [
                    TopicPrompt(id: "wg1", text: "Let's play 20 questions — think of something and I'll guess", label: "20 questions"),
                    TopicPrompt(id: "wg2", text: "Give me a riddle to solve", label: "Riddles"),
                    TopicPrompt(id: "wg3", text: "Let's play a word association game", label: "Word association"),
                    TopicPrompt(id: "wg4", text: "Tell me some mind-bending brain teasers", label: "Brain teasers"),
                    TopicPrompt(id: "wg5", text: "Let's play 'Would You Rather' with creative scenarios", label: "Would you rather")
                ]
            ),
            TopicSubcategory(
                id: "storytelling",
                name: "Interactive Stories",
                description: "Choose-your-own-adventure style",
                prompts: [
                    TopicPrompt(id: "st1", text: "Start a choose-your-own-adventure story set in a fantasy world", label: "Fantasy adventure"),
                    TopicPrompt(id: "st2", text: "Let's create a mystery story together where I make the choices", label: "Mystery story"),
                    TopicPrompt(id: "st3", text: "Start a sci-fi adventure where I'm the captain of a spaceship", label: "Space captain"),
                    TopicPrompt(id: "st4", text: "Create a survival scenario and let me decide what to do", label: "Survival game"),
                    TopicPrompt(id: "st5", text: "Let's play a detective story where I solve the crime", label: "Detective game")
                ]
            )
        ]
    )

    // MARK: - Creative Writing

    private static let creativeWriting = TopicCategory(
        id: "creative",
        name: "Creative Writing",
        icon: "pencil.and.outline",
        color: .pink,
        subcategories: [
            TopicSubcategory(
                id: "writing-prompts",
                name: "Writing Prompts",
                description: "Spark your creativity",
                prompts: [
                    TopicPrompt(id: "wp1", text: "Give me a creative writing prompt about an unexpected discovery", label: "Discovery prompt"),
                    TopicPrompt(id: "wp2", text: "Help me write a short story about time travel", label: "Time travel story"),
                    TopicPrompt(id: "wp3", text: "Write a poem about the beauty of ordinary moments", label: "Poetry"),
                    TopicPrompt(id: "wp4", text: "Help me brainstorm ideas for a novel", label: "Novel ideas"),
                    TopicPrompt(id: "wp5", text: "Let's write a haiku about each season", label: "Seasonal haiku")
                ]
            ),
            TopicSubcategory(
                id: "writing-help",
                name: "Writing Improvement",
                description: "Level up your writing skills",
                prompts: [
                    TopicPrompt(id: "wh1", text: "What are the key elements of great storytelling?", label: "Storytelling tips"),
                    TopicPrompt(id: "wh2", text: "How can I make my writing more engaging and vivid?", label: "Better writing"),
                    TopicPrompt(id: "wh3", text: "Teach me about different narrative structures", label: "Story structures"),
                    TopicPrompt(id: "wh4", text: "What makes dialogue feel natural and compelling?", label: "Dialogue tips"),
                    TopicPrompt(id: "wh5", text: "How do professional writers overcome writer's block?", label: "Writer's block")
                ]
            )
        ]
    )

    // MARK: - Career & Productivity

    private static let career = TopicCategory(
        id: "career",
        name: "Career & Productivity",
        icon: "briefcase.fill",
        color: .cyan,
        subcategories: [
            TopicSubcategory(
                id: "career-advice",
                name: "Career Advice",
                description: "Navigate your professional life",
                prompts: [
                    TopicPrompt(id: "ca1", text: "What skills are most in demand in the job market right now?", label: "In-demand skills"),
                    TopicPrompt(id: "ca2", text: "How do I prepare for a job interview at a tech company?", label: "Interview prep"),
                    TopicPrompt(id: "ca3", text: "What are the best strategies for negotiating a salary?", label: "Salary negotiation"),
                    TopicPrompt(id: "ca4", text: "How can I build a strong professional network?", label: "Networking tips"),
                    TopicPrompt(id: "ca5", text: "What are some good side hustle ideas for extra income?", label: "Side hustles")
                ]
            ),
            TopicSubcategory(
                id: "productivity",
                name: "Productivity",
                description: "Get more done with less stress",
                prompts: [
                    TopicPrompt(id: "pr1", text: "What are the best productivity techniques for deep work?", label: "Deep work"),
                    TopicPrompt(id: "pr2", text: "How can I stop procrastinating and stay focused?", label: "Beat procrastination"),
                    TopicPrompt(id: "pr3", text: "What's the best way to manage my time effectively?", label: "Time management"),
                    TopicPrompt(id: "pr4", text: "Help me create a morning routine for maximum productivity", label: "Morning routine"),
                    TopicPrompt(id: "pr5", text: "What are the best tools and apps for staying organized?", label: "Organization tools")
                ]
            ),
            TopicSubcategory(
                id: "leadership",
                name: "Leadership",
                description: "Lead teams and inspire others",
                prompts: [
                    TopicPrompt(id: "ld1", text: "What makes a great leader in today's workplace?", label: "Leadership traits"),
                    TopicPrompt(id: "ld2", text: "How do I give constructive feedback to my team?", label: "Giving feedback"),
                    TopicPrompt(id: "ld3", text: "What are effective strategies for managing remote teams?", label: "Remote management"),
                    TopicPrompt(id: "ld4", text: "How do I handle conflict in the workplace?", label: "Conflict resolution"),
                    TopicPrompt(id: "ld5", text: "What books should every aspiring leader read?", label: "Leadership books")
                ]
            )
        ]
    )

    // MARK: - Health & Wellness

    private static let health = TopicCategory(
        id: "health",
        name: "Health & Wellness",
        icon: "heart.fill",
        color: .green,
        subcategories: [
            TopicSubcategory(
                id: "mental-health",
                name: "Mental Wellness",
                description: "Mind, mindfulness, and stress relief",
                prompts: [
                    TopicPrompt(id: "mh1", text: "What are effective techniques for managing stress and anxiety?", label: "Stress relief"),
                    TopicPrompt(id: "mh2", text: "Guide me through a simple mindfulness meditation", label: "Meditation guide"),
                    TopicPrompt(id: "mh3", text: "What are the science-backed benefits of journaling?", label: "Journaling benefits"),
                    TopicPrompt(id: "mh4", text: "How can I improve my sleep quality naturally?", label: "Better sleep"),
                    TopicPrompt(id: "mh5", text: "What daily habits contribute most to mental well-being?", label: "Wellness habits")
                ]
            ),
            TopicSubcategory(
                id: "fitness",
                name: "Fitness & Exercise",
                description: "Stay active and healthy",
                prompts: [
                    TopicPrompt(id: "ft1", text: "Design a simple home workout routine for beginners", label: "Home workout"),
                    TopicPrompt(id: "ft2", text: "What are the best exercises for improving posture?", label: "Posture exercises"),
                    TopicPrompt(id: "ft3", text: "How do I start a running routine from scratch?", label: "Start running"),
                    TopicPrompt(id: "ft4", text: "What stretches should I do if I sit at a desk all day?", label: "Desk stretches"),
                    TopicPrompt(id: "ft5", text: "Explain the benefits of different types of exercise", label: "Exercise types")
                ]
            ),
            TopicSubcategory(
                id: "nutrition",
                name: "Nutrition",
                description: "Eat well, feel great",
                prompts: [
                    TopicPrompt(id: "nu1", text: "What does a balanced diet actually look like?", label: "Balanced diet"),
                    TopicPrompt(id: "nu2", text: "What are superfoods and do they really make a difference?", label: "Superfoods"),
                    TopicPrompt(id: "nu3", text: "Help me plan healthy meals for the week", label: "Meal planning"),
                    TopicPrompt(id: "nu4", text: "What are the pros and cons of intermittent fasting?", label: "Fasting"),
                    TopicPrompt(id: "nu5", text: "How much water should I actually drink every day?", label: "Hydration")
                ]
            )
        ]
    )

    // MARK: - Technology

    private static let technology = TopicCategory(
        id: "technology",
        name: "Technology",
        icon: "cpu.fill",
        color: .teal,
        subcategories: [
            TopicSubcategory(
                id: "ai-ml",
                name: "AI & Machine Learning",
                description: "Understanding artificial intelligence",
                prompts: [
                    TopicPrompt(id: "ai1", text: "How does ChatGPT and other large language models actually work?", label: "How LLMs work"),
                    TopicPrompt(id: "ai2", text: "What jobs will AI create vs replace in the next decade?", label: "AI and jobs"),
                    TopicPrompt(id: "ai3", text: "Explain the difference between AI, machine learning, and deep learning", label: "AI vs ML"),
                    TopicPrompt(id: "ai4", text: "What are the most exciting AI applications right now?", label: "Cool AI uses"),
                    TopicPrompt(id: "ai5", text: "Should we be worried about artificial general intelligence?", label: "AGI concerns")
                ]
            ),
            TopicSubcategory(
                id: "cybersecurity",
                name: "Cybersecurity",
                description: "Stay safe in the digital world",
                prompts: [
                    TopicPrompt(id: "cs1", text: "What are the most important things I can do to protect my online privacy?", label: "Privacy tips"),
                    TopicPrompt(id: "cs2", text: "How do hackers actually break into systems?", label: "Hacking explained"),
                    TopicPrompt(id: "cs3", text: "What is a VPN and do I really need one?", label: "VPN guide"),
                    TopicPrompt(id: "cs4", text: "How can I tell if an email or website is a scam?", label: "Spot scams"),
                    TopicPrompt(id: "cs5", text: "What's the best way to manage all my passwords?", label: "Password tips")
                ]
            ),
            TopicSubcategory(
                id: "future-tech",
                name: "Future Technology",
                description: "What's coming next",
                prompts: [
                    TopicPrompt(id: "fut1", text: "What technologies will transform our lives in the next 10 years?", label: "Future tech"),
                    TopicPrompt(id: "fut2", text: "How close are we to having self-driving cars everywhere?", label: "Self-driving cars"),
                    TopicPrompt(id: "fut3", text: "What is quantum computing and why does it matter?", label: "Quantum computing"),
                    TopicPrompt(id: "fut4", text: "Will we ever colonize Mars? What would it take?", label: "Mars colony"),
                    TopicPrompt(id: "fut5", text: "What is the metaverse and is it actually going to happen?", label: "Metaverse")
                ]
            )
        ]
    )

    // MARK: - Travel

    private static let travel = TopicCategory(
        id: "travel",
        name: "Travel & Adventure",
        icon: "airplane",
        color: .mint,
        subcategories: [
            TopicSubcategory(
                id: "destinations",
                name: "Destinations",
                description: "Where to go next",
                prompts: [
                    TopicPrompt(id: "ds1", text: "What are the most underrated travel destinations in the world?", label: "Hidden gems"),
                    TopicPrompt(id: "ds2", text: "Plan a perfect week-long trip to Japan for a first-timer", label: "Japan trip"),
                    TopicPrompt(id: "ds3", text: "What are the best road trip routes in the United States?", label: "US road trips"),
                    TopicPrompt(id: "ds4", text: "Where should I travel if I love history and architecture?", label: "History travel"),
                    TopicPrompt(id: "ds5", text: "What are the most beautiful natural wonders to visit?", label: "Natural wonders"),
                    TopicPrompt(id: "ds6", text: "Recommend a budget-friendly international vacation", label: "Budget travel")
                ]
            ),
            TopicSubcategory(
                id: "travel-tips",
                name: "Travel Tips",
                description: "Travel smarter and safer",
                prompts: [
                    TopicPrompt(id: "tt1", text: "What are your best tips for flying long distances comfortably?", label: "Long-haul tips"),
                    TopicPrompt(id: "tt2", text: "How do I pack efficiently for a two-week trip?", label: "Packing tips"),
                    TopicPrompt(id: "tt3", text: "What travel apps and tools should every traveler have?", label: "Travel apps"),
                    TopicPrompt(id: "tt4", text: "How can I find the best deals on flights and hotels?", label: "Travel deals"),
                    TopicPrompt(id: "tt5", text: "What safety precautions should solo travelers take?", label: "Solo travel safety")
                ]
            ),
            TopicSubcategory(
                id: "culture",
                name: "Culture & Customs",
                description: "Understand the places you visit",
                prompts: [
                    TopicPrompt(id: "cu1", text: "What cultural etiquette should I know before visiting East Asia?", label: "Asian etiquette"),
                    TopicPrompt(id: "cu2", text: "Tell me about the most unique cultural traditions around the world", label: "World traditions"),
                    TopicPrompt(id: "cu3", text: "What are the world's most incredible festivals to experience?", label: "Global festivals"),
                    TopicPrompt(id: "cu4", text: "How do greeting customs differ around the world?", label: "Greeting customs")
                ]
            )
        ]
    )

    // MARK: - Food & Cooking

    private static let food = TopicCategory(
        id: "food",
        name: "Food & Cooking",
        icon: "fork.knife",
        color: .brown,
        subcategories: [
            TopicSubcategory(
                id: "recipes",
                name: "Recipes & Cooking",
                description: "Delicious dishes to try",
                prompts: [
                    TopicPrompt(id: "rc1", text: "Give me a simple recipe for an impressive dinner party dish", label: "Dinner party"),
                    TopicPrompt(id: "rc2", text: "What are some easy meals I can meal prep on Sunday?", label: "Meal prep"),
                    TopicPrompt(id: "rc3", text: "Teach me how to make authentic Italian pasta from scratch", label: "Fresh pasta"),
                    TopicPrompt(id: "rc4", text: "What are some quick healthy breakfast ideas?", label: "Quick breakfast"),
                    TopicPrompt(id: "rc5", text: "Help me come up with dinner ideas using chicken, rice, and vegetables", label: "Pantry dinner")
                ]
            ),
            TopicSubcategory(
                id: "food-culture",
                name: "Food Culture",
                description: "The world through its cuisine",
                prompts: [
                    TopicPrompt(id: "fc1", text: "What are the most iconic dishes from different countries?", label: "World dishes"),
                    TopicPrompt(id: "fc2", text: "Tell me about the history of pizza and how it spread worldwide", label: "Pizza history"),
                    TopicPrompt(id: "fc3", text: "What are the key differences between regional BBQ styles in the US?", label: "BBQ styles"),
                    TopicPrompt(id: "fc4", text: "What makes French cuisine so celebrated around the world?", label: "French cuisine"),
                    TopicPrompt(id: "fc5", text: "What are some must-try street foods from around the world?", label: "Street food")
                ]
            ),
            TopicSubcategory(
                id: "cooking-skills",
                name: "Cooking Skills",
                description: "Level up in the kitchen",
                prompts: [
                    TopicPrompt(id: "ck1", text: "What are the essential cooking techniques every home cook should know?", label: "Essential techniques"),
                    TopicPrompt(id: "ck2", text: "How do I properly season food like a chef?", label: "Seasoning guide"),
                    TopicPrompt(id: "ck3", text: "What kitchen tools are worth investing in?", label: "Kitchen tools"),
                    TopicPrompt(id: "ck4", text: "How do I make a perfect steak at home?", label: "Perfect steak"),
                    TopicPrompt(id: "ck5", text: "What are common cooking mistakes beginners make?", label: "Cooking mistakes")
                ]
            )
        ]
    )

    // MARK: - Science

    private static let science = TopicCategory(
        id: "science",
        name: "Science & Nature",
        icon: "atom",
        color: .yellow,
        subcategories: [
            TopicSubcategory(
                id: "space",
                name: "Space & Astronomy",
                description: "Explore the cosmos",
                prompts: [
                    TopicPrompt(id: "sp1", text: "What are the most fascinating things we've learned about space recently?", label: "Space discoveries"),
                    TopicPrompt(id: "sp2", text: "How will the universe eventually end?", label: "End of universe"),
                    TopicPrompt(id: "sp3", text: "Tell me about the most bizarre objects in the universe", label: "Weird space"),
                    TopicPrompt(id: "sp4", text: "What would it be like to visit different planets in our solar system?", label: "Planet tour"),
                    TopicPrompt(id: "sp5", text: "How do black holes work and what happens if you fall into one?", label: "Black holes"),
                    TopicPrompt(id: "sp6", text: "Are we alone in the universe? What's the evidence?", label: "Alien life")
                ]
            ),
            TopicSubcategory(
                id: "biology",
                name: "Biology & Nature",
                description: "Life on Earth and beyond",
                prompts: [
                    TopicPrompt(id: "bi1", text: "What are the most incredible animal adaptations in nature?", label: "Cool adaptations"),
                    TopicPrompt(id: "bi2", text: "How does evolution actually work?", label: "Evolution explained"),
                    TopicPrompt(id: "bi3", text: "What are the most extreme environments where life exists?", label: "Extreme life"),
                    TopicPrompt(id: "bi4", text: "Tell me about the most recent discoveries in human genetics", label: "Genetics news"),
                    TopicPrompt(id: "bi5", text: "What animals are the most intelligent and why?", label: "Smartest animals")
                ]
            ),
            TopicSubcategory(
                id: "earth-science",
                name: "Earth Science",
                description: "Our planet and its systems",
                prompts: [
                    TopicPrompt(id: "es1", text: "How do earthquakes and volcanoes actually work?", label: "Earthquakes"),
                    TopicPrompt(id: "es2", text: "What is climate change and what are the latest projections?", label: "Climate science"),
                    TopicPrompt(id: "es3", text: "Tell me about the most extreme weather phenomena on Earth", label: "Extreme weather"),
                    TopicPrompt(id: "es4", text: "How were the oceans formed and what secrets do they hold?", label: "Ocean mysteries"),
                    TopicPrompt(id: "es5", text: "What would happen if Earth's magnetic field disappeared?", label: "Magnetic field")
                ]
            )
        ]
    )

    // MARK: - History

    private static let history = TopicCategory(
        id: "history",
        name: "History",
        icon: "building.columns.fill",
        color: .gray,
        subcategories: [
            TopicSubcategory(
                id: "ancient",
                name: "Ancient History",
                description: "Civilizations that shaped our world",
                prompts: [
                    TopicPrompt(id: "ah1", text: "What was daily life like in ancient Rome?", label: "Ancient Rome"),
                    TopicPrompt(id: "ah2", text: "How were the Egyptian pyramids actually built?", label: "Pyramids"),
                    TopicPrompt(id: "ah3", text: "Tell me about the rise and fall of the Greek empire", label: "Greek empire"),
                    TopicPrompt(id: "ah4", text: "What are the greatest unsolved mysteries of ancient history?", label: "Ancient mysteries"),
                    TopicPrompt(id: "ah5", text: "How did the Silk Road change the world?", label: "Silk Road")
                ]
            ),
            TopicSubcategory(
                id: "modern-history",
                name: "Modern History",
                description: "Events that shaped today's world",
                prompts: [
                    TopicPrompt(id: "mh1b", text: "What were the most pivotal moments of the 20th century?", label: "20th century"),
                    TopicPrompt(id: "mh2b", text: "How did the Cold War shape the modern world?", label: "Cold War"),
                    TopicPrompt(id: "mh3b", text: "Tell me about the most important inventions that changed humanity", label: "Key inventions"),
                    TopicPrompt(id: "mh4b", text: "What can we learn from the fall of great empires?", label: "Fallen empires"),
                    TopicPrompt(id: "mh5b", text: "How did the internet change society?", label: "Internet era")
                ]
            ),
            TopicSubcategory(
                id: "historical-figures",
                name: "Historical Figures",
                description: "People who changed history",
                prompts: [
                    TopicPrompt(id: "hf1", text: "Who are the most influential people in history and why?", label: "Most influential"),
                    TopicPrompt(id: "hf2", text: "Tell me about unsung heroes who changed the world", label: "Unsung heroes"),
                    TopicPrompt(id: "hf3", text: "What was Leonardo da Vinci really like as a person?", label: "Da Vinci"),
                    TopicPrompt(id: "hf4", text: "Who are the most fascinating women in history?", label: "Women in history"),
                    TopicPrompt(id: "hf5", text: "Tell me about history's greatest explorers and their journeys", label: "Great explorers")
                ]
            )
        ]
    )

    // MARK: - Music

    private static let music = TopicCategory(
        id: "music",
        name: "Music",
        icon: "music.note.list",
        color: .pink,
        subcategories: [
            TopicSubcategory(
                id: "discover-music",
                name: "Music Discovery",
                description: "Find your next favorite artist",
                prompts: [
                    TopicPrompt(id: "dm1", text: "Recommend some albums that everyone should listen to at least once", label: "Essential albums"),
                    TopicPrompt(id: "dm2", text: "What are some great artists I might not have heard of?", label: "Hidden artists"),
                    TopicPrompt(id: "dm3", text: "Create a playlist vibe for a rainy Sunday afternoon", label: "Rainy day vibes"),
                    TopicPrompt(id: "dm4", text: "What music genres are blowing up right now?", label: "Trending genres"),
                    TopicPrompt(id: "dm5", text: "Recommend music based on my mood — I'm feeling nostalgic", label: "Nostalgic music")
                ]
            ),
            TopicSubcategory(
                id: "music-history",
                name: "Music History",
                description: "Stories behind the songs",
                prompts: [
                    TopicPrompt(id: "msh1", text: "How did hip-hop evolve from its origins to today?", label: "Hip-hop history"),
                    TopicPrompt(id: "msh2", text: "What was the British Invasion and how did it change music?", label: "British Invasion"),
                    TopicPrompt(id: "msh3", text: "Tell me about the most iconic concerts in music history", label: "Iconic concerts"),
                    TopicPrompt(id: "msh4", text: "How has technology changed the way music is made?", label: "Tech & music"),
                    TopicPrompt(id: "msh5", text: "What are the greatest songs ever written and why?", label: "Greatest songs")
                ]
            ),
            TopicSubcategory(
                id: "music-theory",
                name: "Music Theory",
                description: "Understand how music works",
                prompts: [
                    TopicPrompt(id: "mth1", text: "Why does certain music make us feel emotional?", label: "Music & emotion"),
                    TopicPrompt(id: "mth2", text: "Explain music theory basics for someone who's never studied it", label: "Theory basics"),
                    TopicPrompt(id: "mth3", text: "What makes a song catchy? The science of earworms", label: "Catchy songs"),
                    TopicPrompt(id: "mth4", text: "How do different cultures approach music differently?", label: "World music")
                ]
            )
        ]
    )

    // MARK: - Sports

    private static let sports = TopicCategory(
        id: "sports",
        name: "Sports",
        icon: "sportscourt.fill",
        color: .green,
        subcategories: [
            TopicSubcategory(
                id: "sports-talk",
                name: "Sports Talk",
                description: "Discuss the games",
                prompts: [
                    TopicPrompt(id: "spt1", text: "What's happening in the NFL, NBA, or MLB this season?", label: "Season update"),
                    TopicPrompt(id: "spt2", text: "Who are the greatest athletes of all time in each major sport?", label: "GOATs"),
                    TopicPrompt(id: "spt3", text: "What are the most exciting upcoming sporting events?", label: "Upcoming events"),
                    TopicPrompt(id: "spt4", text: "Tell me about the most incredible underdog stories in sports", label: "Underdog stories"),
                    TopicPrompt(id: "spt5", text: "Which sport has the most athletic competitors and why?", label: "Most athletic")
                ]
            ),
            TopicSubcategory(
                id: "sports-analysis",
                name: "Sports Analysis",
                description: "Deep dives into the games",
                prompts: [
                    TopicPrompt(id: "sa1", text: "How has analytics changed the way sports teams compete?", label: "Sports analytics"),
                    TopicPrompt(id: "sa2", text: "What makes the perfect basketball player?", label: "Perfect player"),
                    TopicPrompt(id: "sa3", text: "Compare the most dominant dynasties in sports history", label: "Dynasties"),
                    TopicPrompt(id: "sa4", text: "How has technology improved athletic performance?", label: "Sports tech"),
                    TopicPrompt(id: "sa5", text: "What are the most controversial moments in sports history?", label: "Controversies")
                ]
            ),
            TopicSubcategory(
                id: "fitness-sports",
                name: "Getting Active",
                description: "Start playing and competing",
                prompts: [
                    TopicPrompt(id: "fs1", text: "What sports are best for adults who want to start competing?", label: "Adult sports"),
                    TopicPrompt(id: "fs2", text: "How do I train for my first 5K race?", label: "First 5K"),
                    TopicPrompt(id: "fs3", text: "What are the best outdoor activities for exercise?", label: "Outdoor activities"),
                    TopicPrompt(id: "fs4", text: "How do I get better at golf as a beginner?", label: "Golf tips"),
                    TopicPrompt(id: "fs5", text: "What martial art is best for self-defense?", label: "Martial arts")
                ]
            )
        ]
    )
}
