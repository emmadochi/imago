// lib/data/reading_plans_data.dart

import '../models/reading_plan_models.dart';

final List<ReadingPlan> kReadingPlans = [
  // 0. 9-Day Psalms of Power & Break Forth
  ReadingPlan(
    id: '9_day_psalms',
    title: '9-Day Psalms of Break Forth',
    subtitle: '9 Days of Divine Protection & Favor',
    description: 'Immerse your spirit in 9 powerful Psalms of victory, divine shield, healing, peace, and divine break forth.',
    durationDays: 9,
    category: '9-Day',
    iconName: 'auto_awesome',
    days: [
      ReadingPlanDay(
        dayNumber: 1,
        title: 'Day 1: The Shepherd\'s Provision',
        scriptureReferences: ['Psalm 23'],
        devotionalText:
            'The Lord is your Shepherd; you lack nothing. He makes you lie down in green pastures and leads you beside quiet waters. He restores your soul. Even in the valley of the shadow of death, fear no evil, for His rod and staff comfort you.',
        reflectionQuestion: 'In what area of your life do you need to trust the Shepherd’s leading and rest today?',
      ),
      ReadingPlanDay(
        dayNumber: 2,
        title: 'Day 2: Secret Place of Protection',
        scriptureReferences: ['Psalm 91'],
        devotionalText:
            'Whoever dwells in the shelter of the Most High will rest in the shadow of the Almighty. He will save you from the fowler’s snare and cover you with His feathers. No harm will overtake you, no disaster will come near your tent.',
        reflectionQuestion: 'Declare God\'s protection over your family and home as you meditate on Psalm 91.',
      ),
      ReadingPlanDay(
        dayNumber: 3,
        title: 'Day 3: Courage Over Fear',
        scriptureReferences: ['Psalm 27'],
        devotionalText:
            'The Lord is my light and my salvation—whom shall I fear? The Lord is the stronghold of my life—of whom shall I be afraid? Though an army besiege me, my heart will not fear; though war break out against me, even then I will be confident.',
        reflectionQuestion: 'What fear or uncertainty are you handing over completely to God today?',
      ),
      ReadingPlanDay(
        dayNumber: 4,
        title: 'Day 4: Deliverance & Angelic Shield',
        scriptureReferences: ['Psalm 34'],
        devotionalText:
            'I sought the Lord, and He answered me; He delivered me from all my fears. Those who look to Him are radiant; their faces are never covered with shame. The angel of the Lord encamps around those who fear Him, and He delivers them.',
        reflectionQuestion: 'Praise God for at least three specific deliverances He has worked in your journey.',
      ),
      ReadingPlanDay(
        dayNumber: 5,
        title: 'Day 5: Unshakable Refuge & Peace',
        scriptureReferences: ['Psalm 46'],
        devotionalText:
            'God is our refuge and strength, an ever-present help in trouble. Therefore we will not fear, though the earth give way and the mountains fall into the heart of the sea. Be still, and know that He is God.',
        reflectionQuestion: 'Take 2 minutes of quiet stillness to allow God\'s peace to quiet every rushing thought.',
      ),
      ReadingPlanDay(
        dayNumber: 6,
        title: 'Day 6: Divine Healing & Compassion',
        scriptureReferences: ['Psalm 103'],
        devotionalText:
            'Praise the Lord, my soul, and forget not all His benefits—who forgives all your sins and heals all your diseases, who redeems your life from the pit and crowns you with love and compassion.',
        reflectionQuestion: 'Thank God for His healing power in your spirit, mind, and physical body.',
      ),
      ReadingPlanDay(
        dayNumber: 7,
        title: 'Day 7: Constant Guardian & Guide',
        scriptureReferences: ['Psalm 121'],
        devotionalText:
            'I lift up my eyes to the mountains—where does my help come from? My help comes from the Lord, the Maker of heaven and earth. The Lord will keep your going out and your coming in from this time forth and forevermore.',
        reflectionQuestion: 'How does knowing that God never sleeps give you rest tonight?',
      ),
      ReadingPlanDay(
        dayNumber: 8,
        title: 'Day 8: Wonderfully Made & Known',
        scriptureReferences: ['Psalm 139'],
        devotionalText:
            'You have searched me, Lord, and You know me. You created my inmost being; You knit me together in my mother\'s womb. I praise You because I am fearfully and wonderfully made; Your works are wonderful, I know that full well.',
        reflectionQuestion: 'Embrace your identity as God\'s beloved creation today. What is He saying about your worth?',
      ),
      ReadingPlanDay(
        dayNumber: 9,
        title: 'Day 9: Total Praise & Victory',
        scriptureReferences: ['Psalm 150'],
        devotionalText:
            'Praise God in His holy place; praise Him in His mighty heavens! Praise Him for His acts of power; praise Him for His surpassing greatness! Let everything that has breath praise the Lord. Praise the Lord!',
        reflectionQuestion: 'Offer a hearty prayer and song of victory to conclude your 9-Day Break Forth journey!',
      ),
    ],
  ),

  // 1. 30-Day Foundations
  ReadingPlan(
    id: '30_day_foundations',
    title: 'Spiritual Foundations',
    subtitle: '30-Day Daily Walk',
    description: 'Discover your divine identity, foundational truths of grace, prayer, and faith in a 30-day journey.',
    durationDays: 30,
    category: '30-Day',
    iconName: 'auto_awesome',
    days: List.generate(30, (i) {
      final dayNum = i + 1;
      final titles = [
        'Divine Purpose & Identity',
        'Unconditional Love',
        'The Power of Prayer',
        'Walking in Faith',
        'Renewing Your Mind',
        'Grace Upon Grace',
        'Overcoming Doubt',
        'The Holy Spirit',
        'Living in Peace',
        'God’s Promises',
        'Forgiveness & Healing',
        'Joy Unspeakable',
        'Strength in Weakness',
        'The Armor of God',
        'Walking in Wisdom',
        'Kingdom Mindset',
        'Light of the World',
        'Trusting His Timing',
        'Abiding in Christ',
        'Spiritual Warfare',
        'Generosity & Blessing',
        'Hope for Tomorrow',
        'Praising in the Storm',
        'Child of God',
        'Refining Fire',
        'The Father Heart',
        'Servant Leadership',
        'Enduring Grace',
        'Victory in Jesus',
        'Unshakable Faith',
      ];
      final verses = [
        ['Jeremiah 29:11-13', 'Ephesians 2:10'],
        ['Romans 8:38-39', '1 John 4:19'],
        ['Philippians 4:6-7', 'Matthew 6:9-13'],
        ['Hebrews 11:1-6', '2 Corinthians 5:7'],
        ['Romans 12:1-2', 'Philippians 4:8'],
        ['Ephesians 2:8-9', '2 Corinthians 12:9'],
        ['James 1:5-8', 'Mark 9:24'],
        ['John 14:16-17', 'Galatians 5:22-23'],
        ['John 14:27', 'Isaiah 26:3'],
        ['2 Peter 1:3-4', 'Joshua 21:45'],
        ['Colossians 3:12-14', 'Psalm 103:1-5'],
        ['Nehemiah 8:10', '1 Peter 1:8-9'],
        ['Isaiah 40:29-31', 'Psalm 46:1-3'],
        ['Ephesians 6:10-18', '2 Corinthians 10:4'],
        ['Proverbs 3:5-6', 'James 3:17'],
        ['Matthew 6:33', 'Colossians 3:1-4'],
        ['Matthew 5:14-16', 'John 8:12'],
        ['Ecclesiastes 3:1-11', 'Galatians 6:9'],
        ['John 15:4-7', 'Psalm 91:1-2'],
        ['1 John 4:4', 'Romans 8:31'],
        ['2 Corinthians 9:6-8', 'Proverbs 11:25'],
        ['Romans 15:13', 'Lamentations 3:22-24'],
        ['Psalm 34:1-4', 'Acts 16:25-26'],
        ['Galatians 4:6-7', '1 John 3:1'],
        ['1 Peter 1:6-7', 'Zechariah 13:9'],
        ['Luke 15:20-24', 'Psalm 103:13'],
        ['Mark 10:43-45', 'Philippians 2:3-5'],
        ['2 Timothy 4:7-8', 'Hebrews 12:1-2'],
        ['1 Corinthians 15:57', 'Romans 8:37'],
        ['Hebrews 10:23', 'Psalm 62:1-2'],
      ];
      final idx = i % titles.length;
      return ReadingPlanDay(
        dayNumber: dayNum,
        title: titles[idx],
        scriptureReferences: verses[idx],
        devotionalText:
            'Day $dayNum focus: God is inviting you into a deeper understanding of ${_devoSnippet(titles[idx])}. Take a moment to reflect on His Word and allow His presence to transform your heart today.',
        reflectionQuestion:
            'How can you apply the truth of ${verses[idx].first} to your life today?',
      );
    }),
  ),

  // 2. 90-Day Wisdom & Psalms
  ReadingPlan(
    id: '90_day_wisdom',
    title: 'Wisdom & Psalms',
    subtitle: '90-Day Journey Through Praise & Proverbs',
    description: 'Immerse your mind in divine wisdom and heartfelt worship over 90 transformative days.',
    durationDays: 90,
    category: '90-Day',
    iconName: 'menu_book',
    days: List.generate(90, (i) {
      final dayNum = i + 1;
      final psalmNum = (i * 2 % 150) + 1;
      final provNum = (i % 31) + 1;
      return ReadingPlanDay(
        dayNumber: dayNum,
        title: 'Day $dayNum: Praise & Insight',
        scriptureReferences: ['Psalm $psalmNum', 'Proverbs $provNum'],
        devotionalText:
            'Today in Psalm $psalmNum and Proverbs $provNum, we see the dual harmony of heartfelt devotion and practical daily wisdom. Worship opens your heart, while wisdom guards your steps.',
        reflectionQuestion: 'What specific verse in Proverbs $provNum speaks to a decision you are facing right now?',
      );
    }),
  ),

  // 3. 30-Day Peace & Overcoming Anxiety
  ReadingPlan(
    id: '30_day_peace',
    title: 'Overcoming Anxiety & Peace',
    subtitle: '30-Day Calm Track',
    description: 'Find weightless rest, freedom from worry, and the serene peace of Christ in 30 days.',
    durationDays: 30,
    category: '30-Day',
    iconName: 'volunteer_activism',
    days: List.generate(30, (i) {
      final dayNum = i + 1;
      final peaceVerses = [
        ['Philippians 4:6-7', 'Isaiah 26:3'],
        ['John 14:27', 'Psalm 23:1-6'],
        ['1 Peter 5:7', 'Matthew 11:28-30'],
        ['Psalm 91:1-16', '2 Timothy 1:7'],
        ['Isaiah 41:10', 'Psalm 46:10'],
        ['Romans 8:31-39', 'Psalm 55:22'],
        ['Psalm 34:4-8', 'Proverbs 3:24-26'],
        ['John 16:33', 'Psalm 121:1-8'],
        ['Joshua 1:9', 'Psalm 27:1-3'],
        ['Matthew 6:25-34', 'Psalm 4:8'],
      ];
      final ref = peaceVerses[i % peaceVerses.length];
      return ReadingPlanDay(
        dayNumber: dayNum,
        title: 'Day $dayNum: Rest in His Presence',
        scriptureReferences: ref,
        devotionalText:
            'Anxiety melts away when we realize how deeply held we are by God. Today’s reading in ${ref.first} reminds us that His peace is not just the absence of trouble, but the presence of Christ.',
        reflectionQuestion: 'What specific anxiety can you surrender into His hands today?',
      );
    }),
  ),

  // 4. 1-Year New Testament
  ReadingPlan(
    id: '365_day_nt',
    title: 'New Testament & Psalms',
    subtitle: '1-Year Complete Walk',
    description: 'Read through the entire New Testament and Psalms over the course of 365 days.',
    durationDays: 365,
    category: '1-Year',
    iconName: 'calendar_today',
    days: List.generate(365, (i) {
      final dayNum = i + 1;
      return ReadingPlanDay(
        dayNumber: dayNum,
        title: 'Day $dayNum: Daily Word',
        scriptureReferences: ['Matthew ${(i % 28) + 1}', 'Psalm ${(i % 150) + 1}'],
        devotionalText:
            'Day $dayNum of your 1-Year Journey. Consistency is the secret to spiritual growth. As you read today, listen for God’s still, small voice speaking directly into your life.',
        reflectionQuestion: 'How does today’s reading encourage your walk with Christ today?',
      );
    }),
  ),
];

String _devoSnippet(String title) {
  switch (title) {
    case 'Divine Purpose & Identity':
      return 'who God created you to be';
    case 'Unconditional Love':
      return 'His boundless love that never fails';
    case 'The Power of Prayer':
      return 'the privilege of conversing with the Father';
    default:
      return title.toLowerCase();
  }
}
