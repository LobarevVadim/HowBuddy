enum LessonExerciseType { singleChoice, multipleSelect, shortAnswer }

class LessonExercise {
  const LessonExercise({
    required this.prompt,
    required this.type,
    required this.options,
    required this.correctAnswers,
    required this.explanation,
  });

  final String prompt;
  final LessonExerciseType type;
  final List<String> options;
  final Set<String> correctAnswers;
  final String explanation;
}

List<LessonExercise> buildExercisesForTopic(String topicId) {
  final isImmortality = topicId == 'immortal';
  final isSmell = topicId == 'poop-smell';

  if (isImmortality) {
    return const [
      LessonExercise(
        prompt: 'What does biological aging describe?',
        type: LessonExerciseType.singleChoice,
        options: [
          'Gradual changes that affect how the body works',
          'A single illness everyone gets at the same age',
          'The body stopping all cell activity at once',
        ],
        correctAnswers: {'Gradual changes that affect how the body works'},
        explanation:
            'Aging involves many gradual changes across cells, tissues, and organs.',
      ),
      LessonExercise(
        prompt:
            'Scientists have already proven a way for humans to live forever.',
        type: LessonExerciseType.singleChoice,
        options: ['True', 'False'],
        correctAnswers: {'False'},
        explanation:
            'There is no proven way to make people immortal. Research is still studying aging and health.',
      ),
      LessonExercise(
        prompt:
            'What are the protective DNA structures at the ends of chromosomes called?',
        type: LessonExerciseType.shortAnswer,
        options: [],
        correctAnswers: {'telomeres'},
        explanation:
            'Telomeres help protect chromosome ends and often shorten as some cells divide.',
      ),
      LessonExercise(
        prompt: 'Which habits can support a longer, healthier life?',
        type: LessonExerciseType.multipleSelect,
        options: [
          'Regular physical activity',
          'Preventive health care',
          'Smoking tobacco',
          'A balanced diet',
        ],
        correctAnswers: {
          'Regular physical activity',
          'Preventive health care',
          'A balanced diet',
        },
        explanation:
            'Healthy habits can lower some risks, though they cannot guarantee a particular lifespan.',
      ),
      LessonExercise(
        prompt: 'Why is aging difficult to solve with one treatment?',
        type: LessonExerciseType.singleChoice,
        options: [
          'It involves many interacting processes',
          'It happens only in one organ',
          'It is caused by one gene in every person',
        ],
        correctAnswers: {'It involves many interacting processes'},
        explanation:
            'Aging has many contributing mechanisms, so one change may not address them all.',
      ),
      LessonExercise(
        prompt:
            'A treatment helping one tissue proves the whole body will not age.',
        type: LessonExerciseType.singleChoice,
        options: ['True', 'False'],
        correctAnswers: {'False'},
        explanation:
            'Results in one tissue or study do not prove that every part of the body stops aging.',
      ),
      LessonExercise(
        prompt:
            'What do scientists call an idea that can be tested with evidence?',
        type: LessonExerciseType.shortAnswer,
        options: [],
        correctAnswers: {'hypothesis'},
        explanation: 'A hypothesis is a testable explanation or prediction.',
      ),
      LessonExercise(
        prompt: 'What makes a longevity study more reliable?',
        type: LessonExerciseType.multipleSelect,
        options: [
          'A suitable comparison group',
          'Enough participants for the question',
          'Results that can be repeated',
          'One person’s story by itself',
        ],
        correctAnswers: {
          'A suitable comparison group',
          'Enough participants for the question',
          'Results that can be repeated',
        },
        explanation:
            'Good study design and repeatable results help separate evidence from coincidence.',
      ),
      LessonExercise(
        prompt:
            'How should you evaluate a headline about an anti-aging discovery?',
        type: LessonExerciseType.singleChoice,
        options: [
          'Read the study and its limitations',
          'Assume the headline includes every detail',
          'Trust it if it promises a dramatic result',
        ],
        correctAnswers: {'Read the study and its limitations'},
        explanation:
            'Headlines can oversimplify. The study itself shows what was tested and what remains unknown.',
      ),
      LessonExercise(
        prompt: 'Which conclusion is best supported by current evidence?',
        type: LessonExerciseType.singleChoice,
        options: [
          'Research may improve healthy lifespan, but immortality is unproven',
          'People can now stop aging completely',
          'Nothing about aging can ever change',
        ],
        correctAnswers: {
          'Research may improve healthy lifespan, but immortality is unproven',
        },
        explanation:
            'Research can improve health and lifespan, but living forever remains speculative.',
      ),
    ];
  }

  if (isSmell) {
    return const [
      LessonExercise(
        prompt: 'What is one major source of the smell of stool?',
        type: LessonExerciseType.singleChoice,
        options: [
          'Gut microbes breaking down food',
          'The body adding perfume during digestion',
          'Air entering the lungs',
        ],
        correctAnswers: {'Gut microbes breaking down food'},
        explanation:
            'Gut microbes break down food and produce compounds that contribute to stool odor.',
      ),
      LessonExercise(
        prompt: 'Stool odor can vary with diet and gut microbes.',
        type: LessonExerciseType.singleChoice,
        options: ['True', 'False'],
        correctAnswers: {'True'},
        explanation:
            'Food choices and the gut microbiome can both affect odor.',
      ),
      LessonExercise(
        prompt: 'Which gas is known for its rotten-egg smell?',
        type: LessonExerciseType.shortAnswer,
        options: [],
        correctAnswers: {'hydrogen sulfide', 'h2s'},
        explanation:
            'Hydrogen sulfide is one sulfur-containing gas with a rotten-egg odor.',
      ),
      LessonExercise(
        prompt: 'What can influence stool odor?',
        type: LessonExerciseType.multipleSelect,
        options: [
          'Foods you eat',
          'Gut microbes',
          'How food is digested',
          'The color of your clothes',
        ],
        correctAnswers: {
          'Foods you eat',
          'Gut microbes',
          'How food is digested',
        },
        explanation:
            'Diet, digestion, and gut microbes all contribute; clothing color does not.',
      ),
      LessonExercise(
        prompt: 'Why can some sulfur-rich foods change odor?',
        type: LessonExerciseType.singleChoice,
        options: [
          'Digestion can produce sulfur-containing compounds',
          'They stop digestion completely',
          'They permanently change your sense of smell',
        ],
        correctAnswers: {'Digestion can produce sulfur-containing compounds'},
        explanation:
            'Some foods contain compounds that gut microbes can turn into odorous substances.',
      ),
      LessonExercise(
        prompt: 'A strong stool odor by itself always means a serious illness.',
        type: LessonExerciseType.singleChoice,
        options: ['True', 'False'],
        correctAnswers: {'False'},
        explanation:
            'Odor varies naturally. Other symptoms and lasting changes matter too.',
      ),
      LessonExercise(
        prompt:
            'What is the community of microorganisms in the gut often called?',
        type: LessonExerciseType.shortAnswer,
        options: [],
        correctAnswers: {'microbiome', 'gut microbiome'},
        explanation:
            'The gut microbiome is the community of microorganisms living in the digestive tract.',
      ),
      LessonExercise(
        prompt:
            'Which changes are good reasons to contact a health professional?',
        type: LessonExerciseType.multipleSelect,
        options: [
          'Blood in your stool',
          'Severe or lasting pain',
          'A persistent sudden change in bowel habits',
          'A brief odor change after a meal',
        ],
        correctAnswers: {
          'Blood in your stool',
          'Severe or lasting pain',
          'A persistent sudden change in bowel habits',
        },
        explanation:
            'Blood, severe pain, or persistent changes deserve medical advice; a short-lived odor change may follow diet.',
      ),
      LessonExercise(
        prompt: 'Why is it useful to notice when an odor change began?',
        type: LessonExerciseType.singleChoice,
        options: [
          'It can help connect the change with diet or other symptoms',
          'It identifies the exact microbe without testing',
          'It proves there is no health concern',
        ],
        correctAnswers: {
          'It can help connect the change with diet or other symptoms',
        },
        explanation:
            'Timing and accompanying symptoms provide useful context, though they do not diagnose a cause.',
      ),
      LessonExercise(
        prompt: 'What is the best takeaway about stool odor?',
        type: LessonExerciseType.singleChoice,
        options: [
          'It often varies, but persistent changes with symptoms should be checked',
          'Any odor means you are sick',
          'Odor is unrelated to digestion',
        ],
        correctAnswers: {
          'It often varies, but persistent changes with symptoms should be checked',
        },
        explanation:
            'Normal variation is common; seek advice for concerning or persistent changes.',
      ),
    ];
  }

  return const [
    LessonExercise(
      prompt: 'What does evolution describe?',
      type: LessonExerciseType.singleChoice,
      options: [
        'Changes in inherited traits in populations over generations',
        'One animal changing its species during its lifetime',
        'A plan that makes every species become human',
      ],
      correctAnswers: {
        'Changes in inherited traits in populations over generations',
      },
      explanation:
          'Evolution happens in populations as inherited traits become more or less common over generations.',
    ),
    LessonExercise(
      prompt: 'Humans evolved from the monkeys alive today.',
      type: LessonExerciseType.singleChoice,
      options: ['True', 'False'],
      correctAnswers: {'False'},
      explanation:
          'Humans and modern monkeys share earlier ancestors; one did not descend from the other.',
    ),
    LessonExercise(
      prompt:
          'What is a trait that helps an organism survive or reproduce called?',
      type: LessonExerciseType.shortAnswer,
      options: [],
      correctAnswers: {'adaptation'},
      explanation:
          'An adaptation is an inherited feature that can help an organism in its environment.',
    ),
    LessonExercise(
      prompt: 'What does natural selection act on?',
      type: LessonExerciseType.multipleSelect,
      options: [
        'Inherited variation among individuals',
        'Differences in survival and reproduction',
        'Traits passed to offspring',
        'A single animal choosing to evolve',
      ],
      correctAnswers: {
        'Inherited variation among individuals',
        'Differences in survival and reproduction',
        'Traits passed to offspring',
      },
      explanation:
          'Natural selection can change a population when inherited traits affect reproductive success.',
    ),
    LessonExercise(
      prompt: 'What can fossils help scientists study?',
      type: LessonExerciseType.singleChoice,
      options: [
        'How organisms and environments changed over time',
        'Exactly what every ancient animal thought',
        'The future of every species',
      ],
      correctAnswers: {'How organisms and environments changed over time'},
      explanation:
          'Fossils preserve evidence of past life and can reveal changes across long periods.',
    ),
    LessonExercise(
      prompt:
          'A single animal usually evolves into a new species during its lifetime.',
      type: LessonExerciseType.singleChoice,
      options: ['True', 'False'],
      correctAnswers: {'False'},
      explanation:
          'Evolution describes population-level changes across generations, not an individual transforming species.',
    ),
    LessonExercise(
      prompt:
          'What is the process called when helpful inherited traits become more common?',
      type: LessonExerciseType.shortAnswer,
      options: [],
      correctAnswers: {'natural selection'},
      explanation:
          'Natural selection is one process that can make helpful inherited traits more common.',
    ),
    LessonExercise(
      prompt:
          'Which evidence can help scientists understand primate evolution?',
      type: LessonExerciseType.multipleSelect,
      options: [
        'Fossils',
        'DNA comparisons',
        'Comparative anatomy',
        'A rumor about an animal',
      ],
      correctAnswers: {'Fossils', 'DNA comparisons', 'Comparative anatomy'},
      explanation:
          'Fossils, DNA, and anatomy provide evidence that can be compared across species.',
    ),
    LessonExercise(
      prompt: 'Why are monkeys still around if evolution happened?',
      type: LessonExerciseType.singleChoice,
      options: [
        'Different lineages adapted to different environments',
        'Evolution stopped before monkeys changed',
        'All monkeys are secretly becoming humans',
      ],
      correctAnswers: {'Different lineages adapted to different environments'},
      explanation:
          'Evolution is branching: different populations follow different paths and can continue to thrive.',
    ),
    LessonExercise(
      prompt: 'Which picture of evolution is most accurate?',
      type: LessonExerciseType.singleChoice,
      options: [
        'A branching tree with many related lineages',
        'A ladder where every species becomes human',
        'A straight line with only one surviving species',
      ],
      correctAnswers: {'A branching tree with many related lineages'},
      explanation:
          'Evolution produces a branching history of related species, not a ladder with a single goal.',
    ),
  ];
}
