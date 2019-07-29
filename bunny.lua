
animal_voices = {bunny="silence", cow="moo", cat="meow", dog="woof"}

function speak(animal)
    local v = animal_voices[animal]
    return v
end